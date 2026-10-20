import re

with open(r'C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Features\MuscuLog\Views\Workouts\ActiveWorkoutView.swift', 'r', encoding='utf-8') as f:
    content = f.read()

old = '''    @ViewBuilder
    private func exerciseSection(_ exercise: CompletedExercise) -> some View {
        Section {
            ForEach(exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                ActiveSetRowView(
                    set: set,
                    onDelete: { deleteSet(setID: set.id, exerciseID: exercise.id) },
                    onWeightChange: { updateSetWeight(setID: set.id, weight: $0) },
                    onRepsChange: { updateSetReps(setID: set.id, reps: $0) }
                )
            }
            Button {
                addSet(to: exercise)
            } label: {
                Label("Ajouter une s\u00e9rie", systemImage: "plus")
            }
            Button {
                insertAfterExercise = exercise
                showingAddExercise = true
            } label: {
                Label("Ajouter un exercice", systemImage: "plus.square")
            }
        } header: {
            HStack {
                Text(exercise.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    exerciseToDeleteID = exercise.id.uuidString
                    exerciseToDeleteName = exercise.exerciseName
                    exerciseToDeleteSetsCount = exercise.sets.count
                    showingDeleteExerciseAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
    }'''

new = '''    @ViewBuilder
    private func exerciseSection(_ exercise: CompletedExercise) -> some View {
        Section {
            ForEach(exercise.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                ActiveSetRowView(
                    set: set,
                    exerciseID: exercise.id,
                    onDelete: { deleteSet(setID: set.id, exerciseID: exercise.id) },
                    onWeightChange: { updateSetWeight(setID: set.id, weight: $0) },
                    onRepsChange: { updateSetReps(setID: set.id, reps: $0) }
                )
            }
            Button {
                addSet(to: exercise)
            } label: {
                Label("Ajouter une s\u00e9rie", systemImage: "plus")
            }
            Button {
                insertAfterExercise = exercise
                showingAddExercise = true
            } label: {
                Label("Ajouter un exercice", systemImage: "plus.square")
            }
        } header: {
            HStack {
                Text(exercise.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    exerciseToDeleteID = exercise.id.uuidString
                    exerciseToDeleteName = exercise.exerciseName
                    exerciseToDeleteSetsCount = exercise.sets.count
                    showingDeleteExerciseAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
    }'''

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Features\MuscuLog\Views\Workouts\ActiveWorkoutView.swift', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Replaced successfully")
else:
    print("Old string not found!")
    # Debug: find the function
    import re
    for m in re.finditer(r'private func exerciseSection', content):
        start = max(0, m.start()-50)
        end = min(len(content), m.end()+500)
        print(f"Found at {m.start()}: {content[start:end]}")
        break