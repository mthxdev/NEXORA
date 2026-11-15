#ifndef CHILL_PROBE_CAPTURE_RING_H
#define CHILL_PROBE_CAPTURE_RING_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ProbeCaptureRing ProbeCaptureRing;

typedef struct {
    uint32_t kind;
    uint32_t frame_count;
    uint32_t source_channel_count;
    uint32_t captured_channel_count;
    int64_t sample_time;
    uint64_t host_time;
    uint32_t timestamp_flags;
    uint64_t generation;
    double sample_rate;
    uint32_t auxiliary;
} ProbeCaptureBlock;

ProbeCaptureRing *ProbeCaptureRingCreate(
    uint32_t capacity,
    uint32_t max_frames_per_block,
    uint32_t max_channels
);

/* Control-thread teardown only, after every producer and consumer is quiescent. */
void ProbeCaptureRingDestroy(ProbeCaptureRing *ring);
int ProbeCaptureRingIsLockFree(const ProbeCaptureRing *ring);
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
);
int ProbeCaptureRingRead(
    ProbeCaptureRing *ring,
    float *destination,
    uint32_t destination_capacity,
    ProbeCaptureBlock *block
);
uint64_t ProbeCaptureRingDroppedCount(const ProbeCaptureRing *ring);
uint64_t ProbeCaptureHostTimeNow(void);

#ifdef __cplusplus
}
#endif

#endif
