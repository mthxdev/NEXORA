#include "ProbeCaptureRing.h"

#include <mach/mach_time.h>
#include <stdatomic.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

struct ProbeCaptureSlot {
    _Atomic uint64_t sequence;
    ProbeCaptureBlock block;
    float *samples; /* Interleaved, bounded by max_frames_per_block * max_channels. */
};

struct ProbeCaptureRing {
    uint32_t capacity;
    uint32_t max_frames_per_block;
    uint32_t max_channels;
    _Atomic uint64_t enqueue_position;
    _Atomic uint64_t dropped_count;
    uint64_t dequeue_position; /* Single control-thread consumer. */
    struct ProbeCaptureSlot *slots;
    float *sample_storage;
};

ProbeCaptureRing *ProbeCaptureRingCreate(
    uint32_t capacity,
    uint32_t max_frames_per_block,
    uint32_t max_channels
) {
    if (capacity < 2 || max_frames_per_block == 0 || max_channels == 0 ||
        (size_t)max_frames_per_block > SIZE_MAX / max_channels) {
        return NULL;
    }
    const size_t samples_per_block = (size_t)max_frames_per_block * max_channels;
    if (samples_per_block > SIZE_MAX / sizeof(float) ||
        (size_t)capacity > SIZE_MAX / sizeof(struct ProbeCaptureSlot) ||
        (size_t)capacity > SIZE_MAX / (samples_per_block * sizeof(float))) {
        return NULL;
    }

    ProbeCaptureRing *ring = calloc(1, sizeof(*ring));
    if (ring == NULL) return NULL;

    ring->slots = calloc(capacity, sizeof(*ring->slots));
    ring->sample_storage = calloc((size_t)capacity * samples_per_block, sizeof(float));
    if (ring->slots == NULL || ring->sample_storage == NULL) {
        free(ring->sample_storage);
        free(ring->slots);
        free(ring);
        return NULL;
    }

    ring->capacity = capacity;
    ring->max_frames_per_block = max_frames_per_block;
    ring->max_channels = max_channels;
    atomic_init(&ring->enqueue_position, 0);
    atomic_init(&ring->dropped_count, 0);

    for (uint32_t index = 0; index < capacity; ++index) {
        atomic_init(&ring->slots[index].sequence, index);
        ring->slots[index].samples = ring->sample_storage + (size_t)index * samples_per_block;
    }
    return ring;
}

void ProbeCaptureRingDestroy(ProbeCaptureRing *ring) {
    if (ring == NULL) return;
    free(ring->sample_storage);
    free(ring->slots);
    free(ring);
}

int ProbeCaptureRingIsLockFree(const ProbeCaptureRing *ring) {
    if (ring == NULL) return 0;
    return atomic_is_lock_free(&ring->enqueue_position) &&
           atomic_is_lock_free(&ring->dropped_count) &&
           atomic_is_lock_free(&ring->slots[0].sequence);
}

static void ProbeCaptureRingRecordDrop(ProbeCaptureRing *ring) {
    atomic_fetch_add_explicit(&ring->dropped_count, 1, memory_order_relaxed);
}

int ProbeCaptureRingWrite(
    ProbeCaptureRing *ring,
    const float *channel_0,
    const float *channel_1,
    uint32_t frame_count,
    uint32_t source_channel_count,
    int64_t sample_time,
    uint64_t host_time,
    uint32_t timestamp_flags,
    uint64_t generation,
    double sample_rate,
    uint32_t kind,
    uint32_t auxiliary
) {
    if (ring == NULL || frame_count > ring->max_frames_per_block ||
        (frame_count > 0 && (source_channel_count == 0 || channel_0 == NULL))) {
        if (ring != NULL) ProbeCaptureRingRecordDrop(ring);
        return 0;
    }

    uint32_t captured_channels = 0;
    if (frame_count > 0) {
        captured_channels = source_channel_count < ring->max_channels
            ? source_channel_count : ring->max_channels;
        if (captured_channels > 1 && channel_1 == NULL) {
            ProbeCaptureRingRecordDrop(ring);
            return 0;
        }
    }

    uint64_t position = atomic_load_explicit(&ring->enqueue_position, memory_order_relaxed);
    struct ProbeCaptureSlot *slot = &ring->slots[position % ring->capacity];
    uint64_t sequence = atomic_load_explicit(&slot->sequence, memory_order_acquire);
    if (sequence != position) {
        ProbeCaptureRingRecordDrop(ring);
        return 0;
    }

    /* One bounded CAS attempt: contention drops this block instead of spinning. */
    if (!atomic_compare_exchange_strong_explicit(
            &ring->enqueue_position, &position, position + 1,
            memory_order_relaxed, memory_order_relaxed)) {
        ProbeCaptureRingRecordDrop(ring);
        return 0;
    }

    slot->block.kind = kind;
    slot->block.frame_count = frame_count;
    slot->block.source_channel_count = source_channel_count;
    slot->block.captured_channel_count = captured_channels;
    slot->block.sample_time = sample_time;
    slot->block.host_time = host_time;
    slot->block.timestamp_flags = timestamp_flags;
    slot->block.generation = generation;
    slot->block.sample_rate = sample_rate;
    slot->block.auxiliary = auxiliary;
    for (uint32_t frame = 0; frame < frame_count; ++frame) {
        const size_t output_index = (size_t)frame * captured_channels;
        slot->samples[output_index] = channel_0[frame];
        if (captured_channels > 1) slot->samples[output_index + 1] = channel_1[frame];
    }

    atomic_store_explicit(&slot->sequence, position + 1, memory_order_release);
    return 1;
}

int ProbeCaptureRingRead(
    ProbeCaptureRing *ring,
    float *destination,
    uint32_t destination_capacity,
    ProbeCaptureBlock *block
) {
    if (ring == NULL || block == NULL) return 0;

    uint64_t position = ring->dequeue_position;
    struct ProbeCaptureSlot *slot = &ring->slots[position % ring->capacity];
    uint64_t sequence = atomic_load_explicit(&slot->sequence, memory_order_acquire);
    if (sequence != position + 1) return 0;

    const size_t sample_count = (size_t)slot->block.frame_count * slot->block.captured_channel_count;
    if (sample_count > destination_capacity || (sample_count > 0 && destination == NULL)) return -1;

    *block = slot->block;
    if (sample_count > 0) {
        memcpy(destination, slot->samples, sample_count * sizeof(float));
    }
    atomic_store_explicit(&slot->sequence, position + ring->capacity, memory_order_release);
    ring->dequeue_position = position + 1;
    return 1;
}

uint64_t ProbeCaptureRingDroppedCount(const ProbeCaptureRing *ring) {
    if (ring == NULL) return 0;
    return atomic_load_explicit(&ring->dropped_count, memory_order_relaxed);
}

uint64_t ProbeCaptureHostTimeNow(void) {
    return mach_absolute_time();
}
