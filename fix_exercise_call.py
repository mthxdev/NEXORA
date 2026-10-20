import re

with open(r'C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Features\MuscuLog\Views\Workouts\ActiveWorkoutView.swift', 'r', encoding='utf-8') as f:
    content = f.read()

pattern = r'(ActiveSetRowView\(\s+set: set,\s+onDelete: \{ deleteSet\(setID: set\.id, exerciseID: exercise\.id\) \},\s+onWeightChange: \{ updateSetWeight\(setID: set\.id, weight: \$\d \}\) \},\s+onRepsChange: \{ updateSetReps\(setID: set\.id, reps: \$\d \}\) \})'

replacement = '''ActiveSetRowView(
                    set: set,
                    exerciseID: exercise.id,
                    onDelete: { deleteSet(setID: set.id, exerciseID: exercise.id) },
                    onWeightChange: { updateSetWeight(setID: set.id, weight: $0) },
                    onRepsChange: { updateSetReps(setID: set.id, reps: $0) }
                )'''

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

if new_content != content:
    with open(r'C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Features\MuscuLog\Views\Workouts\ActiveWorkoutView.swift', 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Replaced successfully")
else:
    print("Pattern not found!")