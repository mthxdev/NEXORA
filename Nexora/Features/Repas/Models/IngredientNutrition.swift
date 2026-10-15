import Foundation

struct IngredientNutrition {
    let caloriesPer100g: Double
    let proteinPer100g: Double
}

struct NutritionDatabase {
    static let shared = NutritionDatabase()

    private let database: [String: IngredientNutrition] = [
        "Poulet": IngredientNutrition(caloriesPer100g: 165, proteinPer100g: 31),
        "Poulet (escalope)": IngredientNutrition(caloriesPer100g: 165, proteinPer100g: 31),
        "Poulet (cuisses)": IngredientNutrition(caloriesPer100g: 220, proteinPer100g: 27),
        "Poulet (filets)": IngredientNutrition(caloriesPer100g: 165, proteinPer100g: 31),
        "Boeuf haché": IngredientNutrition(caloriesPer100g: 250, proteinPer100g: 20),
        "Steak haché": IngredientNutrition(caloriesPer100g: 250, proteinPer100g: 20),
        "Steak": IngredientNutrition(caloriesPer100g: 250, proteinPer100g: 22),
        "Saucisse": IngredientNutrition(caloriesPer100g: 300, proteinPer100g: 14),
        "Jambon": IngredientNutrition(caloriesPer100g: 143, proteinPer100g: 13),
        "Jambon cru": IngredientNutrition(caloriesPer100g: 143, proteinPer100g: 13),
        "Oeufs": IngredientNutrition(caloriesPer100g: 155, proteinPer100g: 13),
        "Oeuf": IngredientNutrition(caloriesPer100g: 155, proteinPer100g: 13),
        "Fromage (emmental)": IngredientNutrition(caloriesPer100g: 335, proteinPer100g: 22),
        "Fromage (mozzarella)": IngredientNutrition(caloriesPer100g: 289, proteinPer100g: 22),
        "Fromage râpé": IngredientNutrition(caloriesPer100g: 335, proteinPer100g: 22),
        "Fromage (raclette)": IngredientNutrition(caloriesPer100g: 350, proteinPer100g: 20),
        "Fromage (comté)": IngredientNutrition(caloriesPer100g: 335, proteinPer100g: 24),
        "Fromage (brie)": IngredientNutrition(caloriesPer100g: 250, proteinPer100g: 15),
        "Mozarella": IngredientNutrition(caloriesPer100g: 289, proteinPer100g: 22),
        "Emmental râpé": IngredientNutrition(caloriesPer100g: 335, proteinPer100g: 22),
        "Riz": IngredientNutrition(caloriesPer100g: 130, proteinPer100g: 2.7),
        "Riz cru": IngredientNutrition(caloriesPer100g: 365, proteinPer100g: 7.4),
        "Pâtes": IngredientNutrition(caloriesPer100g: 371, proteinPer100g: 13),
        "Pâtes cuites": IngredientNutrition(caloriesPer100g: 131, proteinPer100g: 5.1),
        "Pâtes cuites (spaghetti)": IngredientNutrition(caloriesPer100g: 131, proteinPer100g: 5.1),
        "Pommes de terre": IngredientNutrition(caloriesPer100g: 77, proteinPer100g: 2.0),
        "Pommes de terre (bouillies)": IngredientNutrition(caloriesPer100g: 77, proteinPer100g: 2.0),
        "Pommes de terre (frites)": IngredientNutrition(caloriesPer100g: 312, proteinPer100g: 4.0),
        "Purée de pommes de terre": IngredientNutrition(caloriesPer100g: 86, proteinPer100g: 1.8),
        "Semoule": IngredientNutrition(caloriesPer100g: 381, proteinPer100g: 12.7),
        "Semoule cuite": IngredientNutrition(caloriesPer100g: 121, proteinPer100g: 4.0),
        "Farine": IngredientNutrition(caloriesPer100g: 364, proteinPer100g: 10.3),
        "Farine de blé": IngredientNutrition(caloriesPer100g: 364, proteinPer100g: 10.3),
        "Lait": IngredientNutrition(caloriesPer100g: 64, proteinPer100g: 3.3),
        "Lait entier": IngredientNutrition(caloriesPer100g: 64, proteinPer100g: 3.3),
        "Beurre": IngredientNutrition(caloriesPer100g: 717, proteinPer100g: 0.9),
        "Huile d'olive": IngredientNutrition(caloriesPer100g: 884, proteinPer100g: 0),
        "Huile végétale": IngredientNutrition(caloriesPer100g: 884, proteinPer100g: 0),
        "Sucre": IngredientNutrition(caloriesPer100g: 387, proteinPer100g: 0),
        "Sucre blanc": IngredientNutrition(caloriesPer100g: 387, proteinPer100g: 0),
        "Sel": IngredientNutrition(caloriesPer100g: 0, proteinPer100g: 0),
        "Eau": IngredientNutrition(caloriesPer100g: 0, proteinPer100g: 0),
        "Ail": IngredientNutrition(caloriesPer100g: 149, proteinPer100g: 6.4),
        "Oignon": IngredientNutrition(caloriesPer100g: 40, proteinPer100g: 1.1),
        "Oignon rouge": IngredientNutrition(caloriesPer100g: 40, proteinPer100g: 1.1),
        "Oignon vert": IngredientNutrition(caloriesPer100g: 32, proteinPer100g: 1.2),
        "Tomate": IngredientNutrition(caloriesPer100g: 18, proteinPer100g: 0.9),
        "Tomates": IngredientNutrition(caloriesPer100g: 18, proteinPer100g: 0.9),
        "Concombre": IngredientNutrition(caloriesPer100g: 16, proteinPer100g: 0.7),
        "Lettuce": IngredientNutrition(caloriesPer100g: 15, proteinPer100g: 1.4),
        "Laitue": IngredientNutrition(caloriesPer100g: 15, proteinPer100g: 1.4),
        "Fromage blanc": IngredientNutrition(caloriesPer100g: 61, proteinPer100g: 11),
        "Yaourt grec": IngredientNutrition(caloriesPer100g: 59, proteinPer100g: 10),
        "œuf dur": IngredientNutrition(caloriesPer100g: 155, proteinPer100g: 13),
        "Moutarde": IngredientNutrition(caloriesPer100g: 60, proteinPer100g: 4),
        "Vinaigre": IngredientNutrition(caloriesPer100g: 3, proteinPer100g: 0),
        "Ail en poudre": IngredientNutrition(caloriesPer100g: 331, proteinPer100g: 16),
        "Paprika": IngredientNutrition(caloriesPer100g: 282, proteinPer100g: 14),
        "Poivre": IngredientNutrition(caloriesPer100g: 0, proteinPer100g: 0),
        "Thym": IngredientNutrition(caloriesPer100g: 0, proteinPer100g: 0),
        "Romarin": IngredientNutrition(caloriesPer100g: 0, proteinPer100g: 0),
        "Bouillon": IngredientNutrition(caloriesPer100g: 5, proteinPer100g: 0),
        "Fromage à pizza": IngredientNutrition(caloriesPer100g: 265, proteinPer100g: 18),
        "Dough": IngredientNutrition(caloriesPer100g: 250, proteinPer100g: 8),
        "Pâte à pizza": IngredientNutrition(caloriesPer100g: 250, proteinPer100g: 8),
        "Pâte à gnocchis": IngredientNutrition(caloriesPer100g: 250, proteinPer100g: 8),
        "Gnocchis": IngredientNutrition(caloriesPer100g: 143, proteinPer100g: 3.0),
        "Bolognaise": IngredientNutrition(caloriesPer100g: 120, proteinPer100g: 8),
        "Sauce bolognaise": IngredientNutrition(caloriesPer100g: 120, proteinPer100g: 8),
        "Sauce crémeuse": IngredientNutrition(caloriesPer100g: 340, proteinPer100g: 2),
        "Sauce tomate": IngredientNutrition(caloriesPer100g: 35, proteinPer100g: 1),
        "Sauce blanche": IngredientNutrition(caloriesPer100g: 200, proteinPer100g: 2),
        "Confit de canard": IngredientNutrition(caloriesPer100g: 425, proteinPer100g: 19),
        "Canard": IngredientNutrition(caloriesPer100g: 425, proteinPer100g: 19),
        "Haricots blancs": IngredientNutrition(caloriesPer100g: 304, proteinPer100g: 20),
        "Haricots rouges": IngredientNutrition(caloriesPer100g: 317, proteinPer100g: 21),
        "Lentilles": IngredientNutrition(caloriesPer100g: 116, proteinPer100g: 9),
        "Tortilla": IngredientNutrition(caloriesPer100g: 230, proteinPer100g: 6),
        "Champignons": IngredientNutrition(caloriesPer100g: 22, proteinPer100g: 3.1),
        "Aubergine": IngredientNutrition(caloriesPer100g: 25, proteinPer100g: 0.9),
        "Courgette": IngredientNutrition(caloriesPer100g: 17, proteinPer100g: 1.2),
        "Poivron": IngredientNutrition(caloriesPer100g: 20, proteinPer100g: 0.9),
        "Ail des ours": IngredientNutrition(caloriesPer100g: 15, proteinPer100g: 1.4),
        "Échalote": IngredientNutrition(caloriesPer100g: 64, proteinPer100g: 1.4),
        "Cumin": IngredientNutrition(caloriesPer100g: 0, proteinPer100g: 0),
        "Curcuma": IngredientNutrition(caloriesPer100g: 0, proteinPer100g: 0),
        "Coriandre": IngredientNutrition(caloriesPer100g: 0, proteinPer100g: 0),
        "Persil": IngredientNutrition(caloriesPer100g: 0, proteinPer100g: 0),
        "Fromage à tartiner": IngredientNutrition(caloriesPer100g: 250, proteinPer100g: 10),
        "Moutarde forte": IngredientNutrition(caloriesPer100g: 60, proteinPer100g: 4),
        "Ketchup": IngredientNutrition(caloriesPer100g: 106, proteinPer100g: 1),
        "Mayonnaise": IngredientNutrition(caloriesPer100g: 680, proteinPer100g: 1),
        "Fromage (emmental râpé)": IngredientNutrition(caloriesPer100g: 335, proteinPer100g: 22),
        "Oignon caramélisé": IngredientNutrition(caloriesPer100g: 60, proteinPer100g: 1),
        "Lard fumé": IngredientNutrition(caloriesPer100g: 350, proteinPer100g: 18),
        "Lard": IngredientNutrition(caloriesPer100g: 350, proteinPer100g: 18),
        "Chou": IngredientNutrition(caloriesPer100g: 25, proteinPer100g: 1.3),
        "Champignons de Paris": IngredientNutrition(caloriesPer100g: 22, proteinPer100g: 3.1),
        "Vin blanc": IngredientNutrition(caloriesPer100g: 82, proteinPer100g: 0),
        "Vin rouge": IngredientNutrition(caloriesPer100g: 82, proteinPer100g: 0),
        "Boulettes de bœuf": IngredientNutrition(caloriesPer100g: 280, proteinPer100g: 18),
        "Pesto": IngredientNutrition(caloriesPer100g: 550, proteinPer100g: 5),
        "Pâtes cuites (pâtes)": IngredientNutrition(caloriesPer100g: 131, proteinPer100g: 5.1),
        "Fromage (fromage blanc)": IngredientNutrition(caloriesPer100g: 61, proteinPer100g: 11),
        "Fromage (chèvre)": IngredientNutrition(caloriesPer100g: 264, proteinPer100g: 14),
        "Jus de citron": IngredientNutrition(caloriesPer100g: 22, proteinPer100g: 0.3),
        "Fromage râpé (parmesan)": IngredientNutrition(caloriesPer100g: 432, proteinPer100g: 38),
        "Parmesan": IngredientNutrition(caloriesPer100g: 432, proteinPer100g: 38),
        "Pâtes cuites (tagliatelles)": IngredientNutrition(caloriesPer100g: 131, proteinPer100g: 5.1),
        "Lasagnes": IngredientNutrition(caloriesPer100g: 140, proteinPer100g: 6),
        "Pâte à lasagnes": IngredientNutrition(caloriesPer100g: 250, proteinPer100g: 8),
        "Bechamel": IngredientNutrition(caloriesPer100g: 150, proteinPer100g: 2),
        "Fromage râpé (mozarella)": IngredientNutrition(caloriesPer100g: 289, proteinPer100g: 22),
        "Fromage râpé (emmental)": IngredientNutrition(caloriesPer100g: 335, proteinPer100g: 22),
        "Galletas": IngredientNutrition(caloriesPer100g: 450, proteinPer100g: 7),
        "Miel": IngredientNutrition(caloriesPer100g: 304, proteinPer100g: 0.3),
        "Noix": IngredientNutrition(caloriesPer100g: 654, proteinPer100g: 15),
        "Amandes": IngredientNutrition(caloriesPer100g: 579, proteinPer100g: 21),
        "Cacahuètes": IngredientNutrition(caloriesPer100g: 569, proteinPer100g: 25),
        "Pain": IngredientNutrition(caloriesPer100g: 265, proteinPer100g: 9),
        "Pain de campagne": IngredientNutrition(caloriesPer100g: 240, proteinPer100g: 8),
        "Pain grillé": IngredientNutrition(caloriesPer100g: 270, proteinPer100g: 9),
    ]

    func nutrition(for ingredient: String) -> IngredientNutrition? {
        database[ingredient] ?? database[ingredient.lowercased().capitalized]
    }

    func caloriesAndProtein(for ingredient: String, quantity: Double, unit: String) -> (calories: Int, protein: Int) {
        guard let nutrition = nutrition(for: ingredient) else { return (0, 0) }

        let quantityInGrams: Double
        if unit == "g" {
            quantityInGrams = quantity
        } else if unit == "kg" {
            quantityInGrams = quantity * 1000
        } else if unit == "ml" {
            quantityInGrams = quantity
        } else if unit == "l" {
            quantityInGrams = quantity * 1000
        } else if unit == "pcs" || unit == "pc" || unit == "unité" || unit == "unités" {
            quantityInGrams = estimateGrams(for: ingredient, count: quantity)
        } else {
            quantityInGrams = 0
        }

        let factor = quantityInGrams / 100.0
        return (
            calories: Int(factor * nutrition.caloriesPer100g),
            protein: Int(factor * nutrition.proteinPer100g)
        )
    }

    private func estimateGrams(for ingredient: String, count: Double) -> Double {
        let lowercased = ingredient.lowercased()
        if lowercased.contains("œuf") || lowercased.contains("oeuf") {
            return count * 50
        }
        if lowercased.contains("pomme de terre") || lowercased.contains("tomate") || lowercased.contains("oignon") {
            return count * 100
        }
        if lowercased.contains("pain") {
            return count * 50
        }
        if lowercased.contains("courgette") || lowercased.contains("aubergine") || lowercased.contains("concombre") {
            return count * 100
        }
        if lowercased.contains("poivron") {
            return count * 80
        }
        if lowercased.contains("ail") && !lowercased.contains("ail des") && !lowercased.contains("ail en") {
            return count * 5
        }
        if lowercased.contains("gousse") {
            return count * 5
        }
        return count * 50
    }
}
