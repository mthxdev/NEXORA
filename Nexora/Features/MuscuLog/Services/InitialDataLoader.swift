import Foundation
import SwiftData

struct InitialDataLoader {
    static func loadIfEmpty(context: ModelContext) {
        let descriptor = FetchDescriptor<CompletedWorkout>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count > 0 { return }
        
        let formatter = ISO8601DateFormatter()
        
        // Fonction utilitaire pour creer vite
        func makeWorkout(name: String, dateStr: String, exercises: [(String, [(Double, Int)])]) {
            let date = formatter.date(from: dateStr)!
            let workout = CompletedWorkout(programName: "Import Manuel", workoutName: name)
            workout.date = date
            workout.startedAt = date
            workout.finishedAt = date.addingTimeInterval(3600)
            
            for (i, exData) in exercises.enumerated() {
                let exercise = CompletedExercise(exerciseName: exData.0, displayOrder: i)
                for (j, set) in exData.1.enumerated() {
                    let newSet = CompletedSet(weight: set.0, reps: set.1, setNumber: j + 1)
                    exercise.sets.append(newSet)
                }
                workout.exercises.append(exercise)
            }
            context.insert(workout)
        }

        // ========================================
        // 2026-07-11 - Upper
        // ========================================
        makeWorkout(name: "Upper", dateStr: "2026-07-11T08:00:00Z", exercises: [
            ("Tirage vertical prise large", [(39, 10), (45, 10), (52, 10)]),
            ("Tirage horizontal prise V", [(39, 10), (45, 10), (52, 10)]),
            ("Développé couché barre", [(30, 10), (40, 10), (50, 10), (55, 5)]),
            ("Épaules poulie", [(4.5, 10), (5.75, 10), (5.75, 10)]),
            ("Avant bras poulie", [(20.3, 20), (22.5, 20), (24.8, 15)]),
            ("Curl biceps en bas", [(39.4, 10), (41, 10), (50, 5), (45, 2)])
        ])

        // ========================================
        // 2026-07-18 - Upper
        // ========================================
        makeWorkout(name: "Upper", dateStr: "2026-07-18T08:00:00Z", exercises: [
            ("Tirage vertical prise V", [(39, 10), (45, 10), (52, 10)]),
            ("Tirage horizontal prise V", [(39, 10), (45, 10), (52, 10)]),
            ("Développé couché barre", [(20, 5), (30, 5), (40, 5), (50, 10), (55, 5)]),
            ("Élévations latérales", [(4.5, 10), (4.5, 10), (4.5, 6), (5.75, 8)]),
            ("Extension triceps poulie", [(22.5, 12), (24.8, 12), (27, 12)]),
            ("Avant bras poulie", [(15.8, 12), (13.5, 12), (15.8, 12)])
        ])

        // ========================================
        // 2026-07-19 - Lower
        // ========================================
        makeWorkout(name: "Lower", dateStr: "2026-07-19T08:00:00Z", exercises: [
            ("Presse inclinée", [(115, 10), (155, 10), (195, 10), (235, 10)]),
            ("Hip thrust machine", [(35, 10), (40, 10), (50, 10)]),
            ("Leg extension", [(45, 3), (52, 3), (59, 4), (68.3, 10), (75.3, 10)]),
            ("Leg curl", [(39, 3), (45, 3), (52, 4), (59, 10), (66, 10)]),
            ("Mollets (Perfect Squat Machine)", [(50, 10), (60, 10), (70, 10)]),
            ("Abdos", [(0, 30), (0, 30), (0, 30)]) // 3x30sec
        ])

        // ========================================
        // 2026-08-08 - Upper
        // ========================================
        makeWorkout(name: "Upper", dateStr: "2026-08-08T08:00:00Z", exercises: [
            ("Tirage vertical prise large", [(39, 10), (45, 10), (52, 10)]),
            ("Tirage horizontal prise V", [(39, 10), (45, 10), (52, 10)]),
            ("Développé couché barre", [(30, 10), (40, 10), (50, 10)]),
            ("Épaules poulie", [(4.5, 10), (4.5, 10)]),
            ("Avant bras poulie", [(18, 12), (20.3, 15), (22.5, 20)]),
            ("Curl biceps en bas", [(36, 10), (41, 10), (45, 10)])
        ])

        // ========================================
        // 2026-08-09 - Lower
        // ========================================
        makeWorkout(name: "Lower", dateStr: "2026-08-09T08:00:00Z", exercises: [
            ("Presse inclinée", [(75, 10), (115, 10), (155, 10), (195, 10)]),
            ("Hip thrust machine", [(30, 10), (35, 10), (40, 10)]),
            ("Leg extension", [(39, 3), (45, 3), (52, 5), (59, 10), (66, 10)]),
            ("Leg curl", [(32, 3), (39, 3), (45, 4), (52, 10), (59, 10)]),
            ("Mollets (Perfect Squat Machine)", [(50, 10), (55, 10), (60, 10)]),
            ("Abdos", [(0, 30), (0, 30), (0, 30)])
        ])

        // ========================================
        // 2026-08-15 - Upper
        // ========================================
        makeWorkout(name: "Upper", dateStr: "2026-08-15T08:00:00Z", exercises: [
            ("Tirage vertical prise V", [(39, 10), (45, 10), (52, 10)]),
            ("Tirage horizontal prise V", [(39, 10), (45, 10), (52, 10)]),
            ("Développé couché barre", [(30, 10), (40, 10), (50, 10), (60, 2)]),
            ("Élévations latérales", [(4.5, 10), (4.5, 10)]),
            ("Extension triceps poulie", [(22.5, 12), (24.8, 12), (27, 12)]),
            ("Avant bras poulie", [(13.5, 12), (14.75, 12), (15.8, 12)]) // 13,5+1,25 = 14.75
        ])

        // ========================================
        // 2026-08-16 - Lower
        // ========================================
        makeWorkout(name: "Lower", dateStr: "2026-08-16T08:00:00Z", exercises: [
            ("Presse inclinée", [(115, 10), (155, 10), (195, 10)]),
            ("Hip thrust machine", [(30, 10), (40, 10), (50, 10)]),
            ("Leg extension", [(45, 7), (52, 6), (59, 10), (66, 10)]),
            ("Leg curl", [(39, 7), (45, 6), (52, 10), (59, 10)]),
            ("Mollets (Perfect Squat Machine)", [(50, 10), (55, 10), (60, 10)]),
            ("Abdos", [(0, 30), (0, 30), (0, 30)])
        ])

        // ========================================
        // 2026-08-22 - Upper
        // ========================================
        makeWorkout(name: "Upper", dateStr: "2026-08-22T08:00:00Z", exercises: [
            ("Tirage vertical prise large", [(34.3, 10), (41.3, 10), (45, 10)]), // 32+2,3 = 34.3
            ("Tirage horizontal prise V", [(34.3, 10), (41.3, 10), (45, 10)]),
            ("Développé couché barre", [(25, 10), (30, 10), (35, 10)]),
            ("Épaules poulie", [(3.55, 12), (3.55, 15), (3.55, 15)]), // 2,3+1,25 = 3.55
            ("Avant bras poulie", [(15.8, 15), (18, 20), (20.3, 20)]),
            ("Curl biceps en bas", [(32, 10), (36, 10), (41, 10)])
        ])

        // ========================================
        // 2026-08-23 - Lower
        // ========================================
        makeWorkout(name: "Lower", dateStr: "2026-08-23T08:00:00Z", exercises: [
            ("Presse inclinée", [(90, 10), (120, 10), (150, 10)]),
            ("Hip thrust machine", [(25, 10), (30, 10), (40, 10)]),
            ("Leg extension", [(34.3, 10), (45, 10), (52, 10)]), // 32+2,3 = 34.3
            ("Leg curl", [(32, 10), (40.2, 10), (45, 10)]), // 39+1,2 = 40.2
            ("Mollets (Perfect Squat Machine)", [(40, 12), (45, 12), (50, 12)]),
            ("Abdos", [(0, 30), (0, 30), (0, 30)])
        ])

        // ========================================
        // 2026-08-29 - Upper
        // ========================================
        makeWorkout(name: "Upper", dateStr: "2026-08-29T08:00:00Z", exercises: [
            ("Tirage vertical prise V", [(41.3, 10), (47.3, 10), (54.3, 10)]), // +2.3
            ("Tirage horizontal prise V", [(41.3, 10), (47.3, 10), (54.3, 10)]),
            ("Développé couché barre", [(20, 5), (30, 5), (45, 10), (55, 6), (55, 3), (55, 1)]),
            ("Élévations latérales", [(3.55, 10), (4.5, 10), (4.5, 10)]),
            ("Extension triceps poulie", [(22.5, 12), (24.8, 12), (27, 12)]),
            ("Avant bras poulie", [(9, 12), (11.3, 12), (13.5, 12)])
        ])

        // ========================================
        // 2026-09-05 - Upper
        // ========================================
        makeWorkout(name: "Upper", dateStr: "2026-09-05T08:00:00Z", exercises: [
            ("Tirage vertical prise large", [(39, 10), (45, 10), (52, 10)]),
            ("Tirage horizontal prise V", [(39, 10), (45, 10), (52, 10)]),
            ("Développé couché barre", [(20, 5), (30, 5), (50, 10), (55, 7)]),
            ("Épaules poulie", [(3.55, 12), (4.5, 10), (4.5, 10)]),
            ("Avant bras poulie", [(15.8, 20), (20.3, 20), (20.3, 20)]),
            ("Curl biceps en bas", [(36, 10), (41, 10), (30.4, 10)]) // 27+1.1+2.3 = 30.4
        ])

        // ========================================
        // 2026-09-06 - Lower
        // ========================================
        makeWorkout(name: "Lower", dateStr: "2026-09-06T08:00:00Z", exercises: [
            ("Presse inclinée", [(115, 10), (155, 10), (195, 10)]),
            ("Hip thrust machine", [(30, 10), (40, 10), (50, 10)]),
            ("Leg extension", [(45, 7), (52, 5), (59, 10), (66, 10)]),
            ("Leg curl", [(39, 5), (45, 5), (52, 10), (59, 10)]),
            ("Mollets (Perfect Squat Machine)", [(50, 10), (60, 10), (70, 10)]),
            ("Abdos", [(0, 30), (0, 30), (0, 30)])
        ])


        // ========================================
        // 2026-09-12 - Upper
        // ========================================
        makeWorkout(name: "Upper", dateStr: "2026-09-12T08:00:00Z", exercises: [
            ("Tirage vertical prise V", [(41.3, 10), (47.3, 10), (54.3, 10)]),
            ("Tirage horizontal prise V", [(41.3, 10), (47.3, 10), (54.3, 10)]),
            ("Développé couché barre", [(20, 5), (30, 5), (45, 10), (55, 6), (55, 3), (55, 1)]), // 6+3+1x55 -> ça veut dire 3 series
            ("Élévations latérales", [(3.55, 10), (4.5, 10), (4.5, 10)]),
            ("Extension triceps poulie", [(22.5, 12), (24.8, 12), (27, 12)]),
            ("Avant bras poulie barre avec prise sur les côtés", [(9, 12), (11.3, 12), (13.5, 12)])
        ])

        // ========================================
        // 2026-09-13 - Lower
        // ========================================
        makeWorkout(name: "Lower", dateStr: "2026-09-13T08:00:00Z", exercises: [
            ("Presse inclinée", [(115, 10), (155, 10), (195, 10)]),
            ("Hip thrust machine", [(30, 10), (40, 10), (50, 10)]),
            ("Leg extension", [(45, 3), (52, 3), (59, 3), (66, 10), (73, 10)]),
            ("Leg curl", [(39, 5), (45, 5), (52, 10), (59, 10)]),
            ("Mollets (Perfect Squat Machine)", [(40, 5), (50, 5), (60, 10), (70, 10)]),
            ("Abdos", [(0, 30), (0, 30), (0, 30)])
        ])

        // ========================================
        // 2026-09-19 - Upper
        // ========================================
        makeWorkout(name: "Upper", dateStr: "2026-09-19T08:00:00Z", exercises: [
            ("Tirage vertical prise large", [(43.6, 10), (49.6, 10), (56.6, 10)]), // 39+2.3+2.3 = 43.6
            ("Tirage horizontal prise V", [(43.6, 10), (49.6, 10), (54.3, 8)]), // 52+2.3 = 54.3
            ("Développé couché barre", [(20, 10), (30, 10), (45, 10), (55, 5), (50, 5)]),
            ("Épaules poulie", [(4.5, 10), (4.5, 10), (4.5, 10)]),
            ("Avant bras poulie", [(20.3, 20), (20.3, 20), (20.3, 20)]),
            ("Curl biceps en bas", [(36, 10), (27, 10)])
        ])

        // ========================================
        // 2026-09-20 - Lower
        // ========================================
        makeWorkout(name: "Lower", dateStr: "2026-09-20T08:00:00Z", exercises: [
            ("Presse inclinée", [(95, 10), (115, 10), (155, 10), (195, 10), (235, 10)]),
            ("Hip thrust machine", [(30, 10), (40, 10), (60, 10)]),
            ("Leg extension", [(45, 3), (52, 3), (59, 3), (66, 10), (79, 10)]),
            ("Leg curl", [(39, 5), (45, 5), (52, 10), (59, 10)]),
            ("Mollets (Perfect Squat Machine)", [(40, 5), (50, 5), (60, 10), (70, 10)]),
            ("Abdos", [(0, 30), (0, 30), (0, 30)])
        ])

        // ========================================
        // 2026-09-26 - Upper
        // ========================================
        makeWorkout(name: "Upper", dateStr: "2026-09-26T08:00:00Z", exercises: [
            ("Tirage vertical prise V", [(41.3, 10), (47.3, 10)]),
            ("Tirage horizontal prise V", [(41.3, 10), (47.3, 10)]),
            ("Développé couché barre", [(20, 5), (30, 5), (40, 10), (50, 10)]),
            ("Élévations latérales", [(4.5, 10), (4.5, 10)]),
            ("Extension triceps poulie", [(22.5, 12), (27, 10)]),
            ("Avant bras poulie barre", [(13.5, 12), (15.3, 10)])
        ])

        // ========================================
        // 2026-09-27 - Lower
        // ========================================
        makeWorkout(name: "Lower", dateStr: "2026-09-27T08:00:00Z", exercises: [
            ("Presse inclinée", [(95, 10), (135, 10), (195, 10)]),
            ("Hip thrust machine", [(40, 10), (50, 10)]),
            ("Leg extension", [(45, 3), (52, 3), (59, 3), (66, 10)]),
            ("Leg curl", [(39, 5), (45, 5), (52, 10)]),
            ("Mollets (Perfect Squat Machine)", [(50, 10), (60, 10)]),
            ("Crunch poulie", [(27, 10), (31.5, 10), (29.3, 10)])
        ])

        // ========================================
        // 2026-10-03 - Upper
        // ========================================
        makeWorkout(name: "Upper", dateStr: "2026-10-03T08:00:00Z", exercises: [
            ("Tirage vertical prise large", [(41.3, 10), (47.3, 10), (54.3, 10)]),
            ("Tirage horizontal prise V", [(41.3, 10), (47.3, 10), (54.3, 8)]),
            ("Développé couché barre", [(30, 10), (45, 10), (60, 3)]),
            ("Épaules poulie", [(4.5, 10), (4.5, 10), (4.5, 10)]),
            ("Avant bras poulie", [(20.3, 20), (20.3, 20), (20.3, 20)]),
            ("Curl biceps en bas", [(36, 10), (41, 10), (50, 6)])
        ])

        // ========================================
        // 2026-10-04 - Lower
        // ========================================
        makeWorkout(name: "Lower", dateStr: "2026-10-04T08:00:00Z", exercises: [
            ("Presse inclinée", [(95, 10), (115, 10), (155, 10), (195, 10), (235, 10)]),
            ("Hip thrust machine", [(40, 10), (50, 10), (60, 10)]),
            ("Leg extension", [(45, 5), (52, 5), (66, 10), (73, 10)]),
            ("Leg curl", [(45, 10), (52, 10), (59, 10)]),
            ("Abdominal machine en bas", [(28.1, 10), (41, 10), (50, 10)]),
            ("Mollets (Perfect Squat Machine)", [(40, 5), (50, 5), (60, 10), (70, 10)])
        ])

        try? context.save()
        print("Workouts auto-loaded manually successfully.")
    }
}

