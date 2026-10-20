import re

with open(r'C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Features\MuscuLog\Views\Workouts\ActiveWorkoutView.swift', 'r', encoding='utf-8') as f:
    content = f.read()

pattern = r'(    @ViewBuilder\s+private func exerciseSection\(_ exercise: CompletedExercise\) -> some View \{\s+Section \{\s+ForEach\(exercise\.sets\.sorted\(by: \{ \$\.setNumber < \$\.setNumber \}\)\) \{ set in\s+ActiveSetRowView\(\s+set: set,\s+onDelete: \{ deleteSet\(setID: set\.id, exerciseID: exercise\.id\) \},\s+onWeightChange: \{ updateSetWeight\(setID: set\.id, weight: \$\d \}\) \},\s+onRepsChange: \{ updateSetReps\(setID: set\.id, reps: \$\d \)\) \}\)\s+\)\s+Button \{\s+addSet\(to: exercise\)\s+\} label: \{\s+Label\("Ajouter une s\\u00e9rie", systemImage: "plus"\)\s+\}\s+Button \{\s+insertAfterExercise = exercise\s+showingAddExercise = true\s+} label: \{\s+Label\("Ajouter un exercice", systemImage: "plus\.square"\)\s+\}\s+\}\s+header: \{\s+HStack \{\s+Text\(exercise\.exerciseName\)\s+\.font\(\.headline\)\s+\.foregroundStyle\(\.primary\)\s+Spacer\(\)\s+Button \{\s+exerciseToDeleteID = exercise\.id\.uuidString\s+exerciseToDeleteName = exercise\.exerciseName\s+exerciseToDeleteSetsCount = exercise\.sets\.count\s+showingDeleteExerciseAlert = true\s+\}\s+label: \{\s+Image\(systemName: "trash"\)\s+\.foregroundStyle\(\.red\)\s+\.font\(\.subheadline\)\s+\}\s+\.buttonStyle\(\.plain\)\s+\}\s+\}\s+\})'

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

new_content = re.sub(pattern, new, content, flags=re.DOTALL)

if new_content != content:
    with open(r'C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Features\MuscuLog\Views\Workouts\ActiveWorkoutView.swift', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Replaced successfully")
else:
    print("Pattern not found!")
    # Debug: find the function
    for m in re.finditer(r'private func exerciseSection', content):
        start = max(0, m.start()-50)
        end = min(len(content), m.end()+500)
        print(f"Found at {m.start()}: {content[start:end]}")
        break