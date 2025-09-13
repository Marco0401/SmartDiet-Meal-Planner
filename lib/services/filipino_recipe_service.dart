import 'dart:convert';
import 'package:http/http.dart' as http;

class FilipinoRecipeService {
  // Filipino recipe APIs and sources
  static const String _themealdbUrl = 'https://www.themealdb.com/api/json/v1/1';

  /// Fetch Filipino recipes from multiple sources
  static Future<List<dynamic>> fetchFilipinoRecipes(String query) async {
    List<dynamic> allRecipes = [];
    
    try {
      // 1. Try TheMealDB for Filipino dishes
      final mealDbRecipes = await _fetchFromTheMealDB(query);
      allRecipes.addAll(mealDbRecipes);
      
      // 2. Add curated Filipino recipes from local database
      final localFilipinoRecipes = _getCuratedFilipinoRecipes(query);
      allRecipes.addAll(localFilipinoRecipes);
      
      return allRecipes;
    } catch (e) {
      print('Error fetching Filipino recipes: $e');
      // Return local recipes as fallback
      return _getCuratedFilipinoRecipes(query);
    }
  }

  /// Fetch recipes from TheMealDB (has some Filipino dishes)
  static Future<List<dynamic>> _fetchFromTheMealDB(String query) async {
    try {
      final url = '$_themealdbUrl/search.php?s=$query';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meals = data['meals'] as List<dynamic>? ?? [];
        
        // Filter for Filipino dishes and convert format
        return meals.where((meal) {
          final mealName = (meal['strMeal'] as String? ?? '').toLowerCase();
          return _isFilipinoDish(mealName);
        }).map((meal) => {
          'id': 'themealdb_${meal['idMeal']}',
          'title': meal['strMeal'],
          'description': meal['strInstructions']?.substring(0, 100) ?? '',
          'image': meal['strMealThumb'],
          'source': 'TheMealDB',
          'cuisine': 'Filipino',
          'ingredients': _extractMealDbIngredients(meal),
          'instructions': meal['strInstructions'] ?? '',
        }).toList();
      }
    } catch (e) {
      print('TheMealDB error: $e');
    }
    return [];
  }


  /// Get curated Filipino recipes from local database
  static List<dynamic> _getCuratedFilipinoRecipes(String query) {
    final allFilipinoRecipes = [
      // Filipino Breakfast Recipes
      {
        'id': 'local_filipino_breakfast_1',
        'title': 'Tapsilog',
        'description': 'Traditional Filipino breakfast with cured beef, garlic rice, and fried egg',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Tapa (cured beef)', 'Garlic rice', 'Eggs', 'Soy sauce', 'Vinegar'],
        'instructions': '1. Marinate beef strips in soy sauce, vinegar, garlic, and black pepper for at least 30 minutes.\n2. Heat oil in a pan and cook the marinated beef until tender and slightly caramelized.\n3. For garlic rice: Sauté minced garlic in oil until golden, add cooked rice and mix well.\n4. Fry eggs sunny-side up.\n5. Serve beef over garlic rice with fried egg on top.\n6. Garnish with chopped scallions and serve with vinegar dipping sauce.',
        'nutrition': {'calories': 450, 'protein': 25, 'carbs': 45, 'fat': 18}
      },
      {
        'id': 'local_filipino_breakfast_2',
        'title': 'Champorado',
        'description': 'Sweet chocolate rice porridge with milk',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Glutinous rice', 'Cocoa powder', 'Milk', 'Sugar', 'Salt'],
        'instructions': '1. Rinse glutinous rice until water runs clear.\n2. In a pot, combine rice with water and bring to a boil.\n3. Reduce heat and simmer, stirring occasionally, until rice is tender (about 20 minutes).\n4. Add cocoa powder and mix well until fully incorporated.\n5. Gradually add milk while stirring continuously.\n6. Add sugar to taste and continue cooking until thick and creamy.\n7. Serve hot in bowls, topped with evaporated milk and sugar if desired.',
        'nutrition': {'calories': 380, 'protein': 12, 'carbs': 68, 'fat': 8}
      },
      {
        'id': 'local_filipino_breakfast_3',
        'title': 'Tocino with Garlic Rice',
        'description': 'Sweet cured pork with garlic fried rice',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Tocino (sweet cured pork)', 'Garlic rice', 'Soy sauce', 'Garlic'],
        'instructions': '1. Heat oil in a pan over medium heat.\n2. Add tocino slices and cook for 3-4 minutes on each side.\n3. Add a splash of water and cover to steam for 2-3 minutes until fully cooked.\n4. Remove cover and continue cooking until caramelized and slightly crispy.\n5. For garlic rice: Sauté minced garlic in oil until golden brown.\n6. Add day-old rice and stir-fry for 2-3 minutes until heated through.\n7. Season with salt and pepper to taste.\n8. Serve tocino over garlic rice with atchara (pickled papaya) on the side.',
        'nutrition': {'calories': 520, 'protein': 22, 'carbs': 58, 'fat': 24}
      },
      {
        'id': 'local_filipino_breakfast_4',
        'title': 'Longsilog',
        'description': 'Filipino sausage with garlic rice and fried egg',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Longganisa (Filipino sausage)', 'Garlic rice', 'Eggs', 'Vinegar'],
        'instructions': '1. Prick longganisa sausages with a fork to prevent bursting.\n2. Heat oil in a pan over medium heat.\n3. Add longganisa and cook for 5-6 minutes, turning occasionally.\n4. Add a little water and cover to steam for 3-4 minutes until fully cooked.\n5. Remove cover and continue cooking until caramelized and slightly crispy.\n6. For garlic rice: Sauté minced garlic in oil until golden, add rice and stir-fry.\n7. Fry eggs sunny-side up in the same pan.\n8. Serve longganisa over garlic rice with fried egg and vinegar dipping sauce.',
        'nutrition': {'calories': 480, 'protein': 28, 'carbs': 42, 'fat': 22}
      },
      {
        'id': 'local_filipino_breakfast_5',
        'title': 'Bangusilog',
        'description': 'Fried milkfish with garlic rice and fried egg',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Bangus (milkfish)', 'Garlic rice', 'Eggs', 'Salt', 'Pepper'],
        'instructions': '1. Clean and scale the bangus (milkfish), remove gills and innards.\n2. Make diagonal cuts on both sides of the fish.\n3. Season with salt, pepper, and calamansi juice. Let marinate for 15 minutes.\n4. Heat oil in a pan over medium-high heat.\n5. Fry the bangus for 5-6 minutes on each side until golden and crispy.\n6. For garlic rice: Sauté minced garlic in oil until golden, add rice and stir-fry.\n7. Fry eggs sunny-side up.\n8. Serve bangus over garlic rice with fried egg, tomatoes, and vinegar dipping sauce.',
        'nutrition': {'calories': 420, 'protein': 32, 'carbs': 38, 'fat': 18}
      },
      {
        'id': 'local_filipino_breakfast_6',
        'title': 'Arroz Caldo',
        'description': 'Filipino chicken rice porridge with ginger',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Chicken', 'Rice', 'Ginger', 'Garlic', 'Fish sauce', 'Green onions'],
        'instructions': '1. Heat oil in a large pot over medium heat.\n2. Sauté minced garlic and ginger until fragrant.\n3. Add chicken pieces and cook until lightly browned.\n4. Add rice and stir for 2-3 minutes until rice is slightly toasted.\n5. Pour in chicken broth and bring to a boil.\n6. Reduce heat and simmer for 20-25 minutes, stirring occasionally.\n7. Add fish sauce, salt, and pepper to taste.\n8. Continue cooking until rice is tender and mixture is creamy.\n9. Garnish with chopped scallions, fried garlic, and hard-boiled eggs.\n10. Serve hot with calamansi and fish sauce on the side.',
        'nutrition': {'calories': 380, 'protein': 22, 'carbs': 52, 'fat': 12}
      },
      
      // Filipino Lunch Recipes
      {
        'id': 'local_filipino_lunch_1',
        'title': 'Adobo',
        'description': 'Classic Filipino dish with meat marinated in soy sauce and vinegar',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Chicken or pork', 'Soy sauce', 'Vinegar', 'Garlic', 'Bay leaves', 'Black pepper'],
        'instructions': '1. Cut chicken or pork into serving pieces.\n2. In a bowl, combine soy sauce, vinegar, minced garlic, bay leaves, and black pepper.\n3. Add meat to marinade and let sit for at least 30 minutes.\n4. Heat oil in a pot and brown the meat on all sides.\n5. Pour in the marinade and bring to a boil.\n6. Reduce heat and simmer for 30-40 minutes until meat is tender.\n7. Add water if needed to prevent drying out.\n8. Simmer until sauce is reduced and meat is glazed.\n9. Serve hot with steamed rice and vegetables.',
        'nutrition': {'calories': 480, 'protein': 35, 'carbs': 8, 'fat': 32}
      },
      {
        'id': 'local_filipino_lunch_2',
        'title': 'Sinigang',
        'description': 'Sour tamarind soup with meat and vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Pork or fish', 'Tamarind', 'Vegetables', 'Fish sauce', 'Garlic', 'Onion'],
        'instructions': '1. Boil water in a large pot and add tamarind paste or fresh tamarind.\n2. Add meat (pork ribs or fish) and simmer for 20-30 minutes until tender.\n3. Add onions and tomatoes, simmer for 5 minutes.\n4. Add vegetables in order of cooking time: radish, then okra, then eggplant.\n5. Add leafy vegetables (kangkong or spinach) last.\n6. Season with fish sauce, salt, and pepper to taste.\n7. Add more tamarind if you want it more sour.\n8. Simmer for 2-3 minutes until vegetables are tender.\n9. Serve hot with steamed rice and fish sauce on the side.',
        'nutrition': {'calories': 420, 'protein': 28, 'carbs': 25, 'fat': 22}
      },
      {
        'id': 'local_filipino_lunch_3',
        'title': 'Kare-kare',
        'description': 'Peanut stew with meat and vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Beef or pork', 'Peanut butter', 'Vegetables', 'Shrimp paste', 'Garlic'],
        'instructions': '1. Boil oxtail or beef until very tender (1-2 hours).\n2. In a separate pot, sauté garlic and onions until soft.\n3. Add peanut butter and stir until well incorporated.\n4. Add annatto powder for color and stir.\n5. Pour in beef broth and bring to a boil.\n6. Add the cooked meat and simmer for 15 minutes.\n7. Add vegetables: string beans, eggplant, and bok choy.\n8. Simmer for 5-7 minutes until vegetables are tender.\n9. Season with fish sauce and salt to taste.\n10. Serve hot with steamed rice and bagoong (shrimp paste) on the side.',
        'nutrition': {'calories': 580, 'protein': 32, 'carbs': 18, 'fat': 42}
      },
      {
        'id': 'local_filipino_lunch_4',
        'title': 'Bicol Express',
        'description': 'Spicy pork stew with coconut milk and chili peppers',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Pork', 'Coconut milk', 'Chili peppers', 'Shrimp paste', 'Garlic', 'Onion'],
        'instructions': '1. Cut pork into bite-sized pieces.\n2. Heat oil in a pan and sauté garlic and onions until fragrant.\n3. Add pork and cook until lightly browned.\n4. Add coconut milk and bring to a boil.\n5. Reduce heat and simmer for 30-40 minutes until pork is tender.\n6. Add shrimp paste and mix well.\n7. Add chili peppers and simmer for 5-10 minutes.\n8. Add more coconut milk if needed.\n9. Season with fish sauce and salt to taste.\n10. Serve hot with steamed rice.',
        'nutrition': {'calories': 520, 'protein': 28, 'carbs': 12, 'fat': 38}
      },
      {
        'id': 'local_filipino_lunch_5',
        'title': 'Laing',
        'description': 'Taro leaves cooked in coconut milk with chili',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Taro leaves', 'Coconut milk', 'Chili peppers', 'Shrimp paste', 'Garlic'],
        'instructions': '1. Wash taro leaves thoroughly and pat dry.\n2. Heat oil in a pan and sauté garlic, onions, and ginger until fragrant.\n3. Add shrimp paste and cook for 2-3 minutes.\n4. Add coconut milk and bring to a boil.\n5. Add taro leaves and mix well.\n6. Add chili peppers and simmer for 15-20 minutes.\n7. Stir occasionally and add more coconut milk if needed.\n8. Season with fish sauce and salt to taste.\n9. Simmer until taro leaves are tender and sauce is thick.\n10. Serve hot with steamed rice.',
        'nutrition': {'calories': 380, 'protein': 8, 'carbs': 22, 'fat': 32}
      },
      {
        'id': 'local_filipino_lunch_6',
        'title': 'Paksiw na Bangus',
        'description': 'Milkfish cooked in vinegar and fish sauce',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Bangus (milkfish)', 'Vinegar', 'Fish sauce', 'Garlic', 'Ginger'],
        'instructions': '1. Clean and scale the bangus (milkfish), remove gills and innards.\n2. Make diagonal cuts on both sides of the fish.\n3. In a pot, combine vinegar, fish sauce, water, garlic, ginger, and peppercorns.\n4. Bring to a boil and add the fish.\n5. Add onions and simmer for 10-15 minutes.\n6. Add vegetables (eggplant, okra, bitter melon) and simmer for 5 minutes.\n7. Season with salt and pepper to taste.\n8. Simmer for another 5 minutes until fish is cooked through.\n9. Serve hot with steamed rice.',
        'nutrition': {'calories': 320, 'protein': 28, 'carbs': 8, 'fat': 18}
      },
      {
        'id': 'local_filipino_lunch_7',
        'title': 'Ginataang Manok',
        'description': 'Chicken cooked in coconut milk with vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Chicken', 'Coconut milk', 'Vegetables', 'Garlic', 'Onion', 'Ginger'],
        'instructions': '1. Cut chicken into serving pieces.\n2. Heat oil in a pot and sauté garlic, onions, and ginger until fragrant.\n3. Add chicken and cook until lightly browned.\n4. Add coconut milk and bring to a boil.\n5. Reduce heat and simmer for 20-30 minutes until chicken is tender.\n6. Add vegetables (potatoes, carrots, green beans) and simmer for 10 minutes.\n7. Add leafy vegetables (malunggay or spinach) last.\n8. Season with fish sauce, salt, and pepper to taste.\n9. Simmer for 5 more minutes until vegetables are tender.\n10. Serve hot with steamed rice.',
        'nutrition': {'calories': 480, 'protein': 32, 'carbs': 18, 'fat': 32}
      },
      {
        'id': 'local_filipino_lunch_8',
        'title': 'Pinakbet',
        'description': 'Mixed vegetables stew with shrimp paste',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Mixed vegetables', 'Shrimp paste', 'Pork', 'Garlic', 'Onion'],
        'instructions': '1. Heat oil in a pan and sauté garlic and onions until fragrant.\n2. Add pork and cook until lightly browned.\n3. Add shrimp paste and cook for 2-3 minutes.\n4. Add vegetables in order: eggplant, okra, bitter melon, string beans.\n5. Add tomatoes and cook for 5 minutes.\n6. Add a little water and simmer for 10-15 minutes.\n7. Add leafy vegetables (kangkong or ampalaya leaves) last.\n8. Season with fish sauce and salt to taste.\n9. Simmer for 5 more minutes until vegetables are tender.\n10. Serve hot with steamed rice.',
        'nutrition': {'calories': 280, 'protein': 12, 'carbs': 32, 'fat': 12}
      },
      
      // Filipino Dinner Recipes
      {
        'id': 'local_filipino_dinner_1',
        'title': 'Lechon Kawali',
        'description': 'Crispy fried pork belly',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Pork belly', 'Garlic', 'Bay leaves', 'Salt', 'Pepper'],
        'instructions': '1. Cut pork belly into large chunks.\n2. In a pot, boil pork with garlic, bay leaves, salt, and pepper for 45-60 minutes until tender.\n3. Remove pork and pat dry completely.\n4. Heat oil in a deep pan or wok to 350°F (175°C).\n5. Carefully add pork pieces and fry for 8-10 minutes until golden and crispy.\n6. Turn occasionally to ensure even cooking.\n7. Remove and drain on paper towels.\n8. Let rest for 5 minutes before cutting into serving pieces.\n9. Serve hot with steamed rice and vinegar dipping sauce.',
        'nutrition': {'calories': 650, 'protein': 28, 'carbs': 12, 'fat': 52}
      },
      {
        'id': 'local_filipino_dinner_2',
        'title': 'Pancit Canton',
        'description': 'Stir-fried noodles with meat and vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Canton noodles', 'Pork or chicken', 'Vegetables', 'Soy sauce', 'Garlic'],
        'instructions': '1. Soak canton noodles in warm water for 10 minutes, then drain.\n2. Heat oil in a large wok or pan over high heat.\n3. Sauté garlic and onions until fragrant.\n4. Add meat (pork or chicken) and cook until lightly browned.\n5. Add vegetables (carrots, cabbage, bell peppers) and stir-fry for 3-4 minutes.\n6. Add soy sauce, oyster sauce, and fish sauce.\n7. Add the soaked noodles and toss everything together.\n8. Add a little water or broth if needed.\n9. Stir-fry for 5-7 minutes until noodles are tender.\n10. Season with salt and pepper to taste.\n11. Garnish with green onions and serve hot.',
        'nutrition': {'calories': 480, 'protein': 22, 'carbs': 68, 'fat': 16}
      },
      {
        'id': 'local_filipino_dinner_3',
        'title': 'Tinolang Manok',
        'description': 'Chicken soup with ginger and vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Chicken', 'Ginger', 'Vegetables', 'Fish sauce', 'Garlic'],
        'instructions': '1. Cut chicken into serving pieces.\n2. Heat oil in a pot and sauté garlic, onions, and ginger until fragrant.\n3. Add chicken and cook until lightly browned.\n4. Add fish sauce and cook for 2-3 minutes.\n5. Add water and bring to a boil.\n6. Reduce heat and simmer for 20-30 minutes until chicken is tender.\n7. Add vegetables (potatoes, carrots, chayote) and simmer for 10 minutes.\n8. Add leafy vegetables (malunggay or spinach) last.\n9. Season with salt and pepper to taste.\n10. Simmer for 5 more minutes and serve hot with steamed rice.',
        'nutrition': {'calories': 380, 'protein': 32, 'carbs': 18, 'fat': 18}
      },
      {
        'id': 'local_filipino_dinner_4',
        'title': 'Crispy Pata',
        'description': 'Deep-fried pork leg with crispy skin',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Pork leg', 'Garlic', 'Bay leaves', 'Salt', 'Pepper'],
        'instructions': 'Boil pork leg until tender, then deep fry until crispy.',
        'nutrition': {'calories': 720, 'protein': 35, 'carbs': 8, 'fat': 58}
      },
      {
        'id': 'local_filipino_dinner_5',
        'title': 'Sisig',
        'description': 'Sizzling pork face and ears with chili and calamansi',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Pork face and ears', 'Chili peppers', 'Calamansi', 'Onion', 'Garlic'],
        'instructions': '1. Boil pork face and ears with garlic, bay leaves, and peppercorns for 1-2 hours until tender.\n2. Remove from water and let cool, then cut into small pieces.\n3. Heat oil in a pan and fry the pork pieces until crispy and golden.\n4. Remove excess oil and add onions, cooking until soft.\n5. Add chili peppers and cook for 2-3 minutes.\n6. Add calamansi juice and mix well.\n7. Season with fish sauce, salt, and pepper to taste.\n8. Add liver spread if desired and mix well.\n9. Serve hot on a sizzling plate with steamed rice and calamansi on the side.',
        'nutrition': {'calories': 520, 'protein': 32, 'carbs': 8, 'fat': 38}
      },
      {
        'id': 'local_filipino_dinner_6',
        'title': 'Kaldereta',
        'description': 'Beef stew with tomato sauce and vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Beef', 'Tomato sauce', 'Vegetables', 'Cheese', 'Garlic', 'Onion'],
        'instructions': '1. Cut beef into cubes and season with salt and pepper.\n2. Heat oil in a pot and brown the beef on all sides.\n3. Add garlic, onions, and bell peppers, sauté until soft.\n4. Add tomato sauce and water, bring to a boil.\n5. Reduce heat and simmer for 1-2 hours until beef is tender.\n6. Add vegetables (potatoes, carrots, green peas) and simmer for 15 minutes.\n7. Add liver spread and mix well.\n8. Add cheese and stir until melted.\n9. Season with fish sauce, salt, and pepper to taste.\n10. Simmer for 5 more minutes and serve hot with steamed rice.',
        'nutrition': {'calories': 580, 'protein': 38, 'carbs': 22, 'fat': 38}
      },
      {
        'id': 'local_filipino_dinner_7',
        'title': 'Mechado',
        'description': 'Beef stew with tomato sauce and potatoes',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Beef', 'Tomato sauce', 'Potatoes', 'Carrots', 'Garlic', 'Onion'],
        'instructions': '1. Cut beef into cubes and make a slit in the center of each piece.\n2. Insert a strip of fat in each slit (optional).\n3. Heat oil in a pot and brown the beef on all sides.\n4. Add garlic, onions, and tomatoes, sauté until soft.\n5. Add tomato sauce and water, bring to a boil.\n6. Reduce heat and simmer for 1-2 hours until beef is tender.\n7. Add vegetables (potatoes, carrots) and simmer for 15 minutes.\n8. Add bay leaves and peppercorns.\n9. Season with fish sauce, salt, and pepper to taste.\n10. Simmer for 10 more minutes and serve hot with steamed rice.',
        'nutrition': {'calories': 520, 'protein': 35, 'carbs': 28, 'fat': 32}
      },
      {
        'id': 'local_filipino_dinner_8',
        'title': 'Pork Menudo',
        'description': 'Pork stew with tomato sauce and vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Pork', 'Tomato sauce', 'Vegetables', 'Garlic', 'Onion', 'Bay leaves'],
        'instructions': '1. Cut pork into small cubes and season with salt and pepper.\n2. Heat oil in a pot and brown the pork on all sides.\n3. Add garlic, onions, and tomatoes, sauté until soft.\n4. Add tomato sauce and water, bring to a boil.\n5. Reduce heat and simmer for 30-40 minutes until pork is tender.\n6. Add vegetables (potatoes, carrots, green peas) and simmer for 15 minutes.\n7. Add bay leaves and peppercorns.\n8. Season with fish sauce, salt, and pepper to taste.\n9. Simmer for 10 more minutes and serve hot with steamed rice.',
        'nutrition': {'calories': 480, 'protein': 32, 'carbs': 22, 'fat': 28}
      },
      {
        'id': 'local_filipino_dinner_9',
        'title': 'Pancit Bihon',
        'description': 'Rice noodles stir-fried with meat and vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Bihon noodles', 'Pork or chicken', 'Vegetables', 'Soy sauce', 'Garlic'],
        'instructions': '1. Soak bihon noodles in warm water for 10 minutes, then drain.\n2. Heat oil in a large wok or pan over high heat.\n3. Sauté garlic and onions until fragrant.\n4. Add meat (pork or chicken) and cook until lightly browned.\n5. Add vegetables (carrots, cabbage, bell peppers) and stir-fry for 3-4 minutes.\n6. Add soy sauce, oyster sauce, and fish sauce.\n7. Add the soaked noodles and toss everything together.\n8. Add a little water or broth if needed.\n9. Stir-fry for 5-7 minutes until noodles are tender.\n10. Season with salt and pepper to taste.\n11. Garnish with green onions and serve hot.',
        'nutrition': {'calories': 420, 'protein': 18, 'carbs': 68, 'fat': 12}
      },
      {
        'id': 'local_filipino_dinner_10',
        'title': 'Chicken Inasal',
        'description': 'Grilled chicken marinated in calamansi and annatto',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Chicken', 'Calamansi', 'Annatto', 'Garlic', 'Ginger', 'Vinegar'],
        'instructions': '1. Cut chicken into serving pieces and make diagonal cuts.\n2. In a bowl, combine calamansi juice, annatto powder, garlic, ginger, vinegar, and fish sauce.\n3. Add chicken to marinade and let sit for at least 2 hours.\n4. Preheat grill to medium-high heat.\n5. Grill chicken for 8-10 minutes on each side, basting with marinade.\n6. Continue grilling until chicken is cooked through and charred.\n7. Serve hot with steamed rice and atchara (pickled papaya) on the side.',
        'nutrition': {'calories': 450, 'protein': 42, 'carbs': 8, 'fat': 28}
      },
      
      // Filipino Snacks & Desserts
      {
        'id': 'local_filipino_snack_1',
        'title': 'Lumpia',
        'description': 'Fresh spring rolls with vegetables and meat',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Lumpia wrapper', 'Ground pork', 'Vegetables', 'Garlic', 'Soy sauce'],
        'instructions': '1. Sauté garlic and onions until fragrant.\n2. Add ground pork and cook until browned.\n3. Add vegetables (carrots, cabbage, green beans) and cook until tender.\n4. Season with soy sauce, salt, and pepper to taste.\n5. Let filling cool completely.\n6. Place lumpia wrapper on a flat surface.\n7. Add filling and roll tightly, sealing the edges with water.\n8. Serve fresh with sweet and sour sauce or vinegar dipping sauce.',
        'nutrition': {'calories': 280, 'protein': 12, 'carbs': 32, 'fat': 14}
      },
      {
        'id': 'local_filipino_snack_2',
        'title': 'Turon',
        'description': 'Fried banana spring rolls',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Lumpia wrapper', 'Banana', 'Brown sugar', 'Jackfruit'],
        'instructions': '1. Peel bananas and cut in half lengthwise.\n2. Place lumpia wrapper on a flat surface.\n3. Add banana, jackfruit, and brown sugar.\n4. Roll tightly, sealing the edges with water.\n5. Heat oil in a pan over medium heat.\n6. Fry turon for 3-4 minutes on each side until golden and crispy.\n7. Remove and drain on paper towels.\n8. Serve hot with ice cream or as is.',
        'nutrition': {'calories': 320, 'protein': 4, 'carbs': 58, 'fat': 8}
      },
      {
        'id': 'local_filipino_snack_3',
        'title': 'Halo-halo',
        'description': 'Filipino shaved ice dessert with mixed ingredients',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Shaved ice', 'Sweet beans', 'Jelly', 'Fruit', 'Evaporated milk', 'Ice cream'],
        'instructions': '1. Prepare sweet ingredients: cooked sweet beans, nata de coco, kaong, and jelly.\n2. Add fresh fruits like banana, jackfruit, and mango.\n3. Layer ingredients in a tall glass.\n4. Top with shaved ice.\n5. Drizzle with evaporated milk and condensed milk.\n6. Add a scoop of ice cream on top.\n7. Garnish with leche flan or ube halaya.\n8. Serve immediately with a spoon and straw.',
        'nutrition': {'calories': 420, 'protein': 8, 'carbs': 68, 'fat': 12}
      },
      {
        'id': 'local_filipino_snack_4',
        'title': 'Bibingka',
        'description': 'Filipino rice cake with coconut and cheese',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Rice flour', 'Coconut milk', 'Cheese', 'Eggs', 'Sugar'],
        'instructions': '1. Preheat oven to 350°F (175°C).\n2. In a bowl, mix rice flour, sugar, and salt.\n3. Add coconut milk and eggs, whisk until smooth.\n4. Grease baking pan and line with banana leaves.\n5. Pour batter into prepared pan.\n6. Top with grated cheese and coconut.\n7. Bake for 25-30 minutes until golden and set.\n8. Let cool slightly before serving.\n9. Serve warm with butter and sugar on top.',
        'nutrition': {'calories': 380, 'protein': 12, 'carbs': 58, 'fat': 12}
      },
      {
        'id': 'local_filipino_snack_5',
        'title': 'Puto',
        'description': 'Steamed rice cakes',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Rice flour', 'Sugar', 'Coconut milk', 'Baking powder'],
        'instructions': '1. In a bowl, mix rice flour, sugar, and baking powder.\n2. Add coconut milk and whisk until smooth.\n3. Let batter rest for 30 minutes.\n4. Prepare steamer and grease puto molds.\n5. Pour batter into molds, filling 3/4 full.\n6. Steam for 15-20 minutes until cooked through.\n7. Let cool slightly before removing from molds.\n8. Serve warm with cheese or butter on top.',
        'nutrition': {'calories': 280, 'protein': 6, 'carbs': 58, 'fat': 4}
      },
      {
        'id': 'local_filipino_snack_6',
        'title': 'Kutsinta',
        'description': 'Brown rice cakes with coconut',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Rice flour', 'Brown sugar', 'Coconut', 'Lye water'],
        'instructions': '1. In a bowl, mix rice flour, brown sugar, and lye water.\n2. Add water gradually while whisking until smooth.\n3. Let batter rest for 30 minutes.\n4. Prepare steamer and grease kutsinta molds.\n5. Pour batter into molds, filling 3/4 full.\n6. Steam for 20-25 minutes until set and firm.\n7. Let cool completely before removing from molds.\n8. Top with grated coconut and serve.',
        'nutrition': {'calories': 320, 'protein': 4, 'carbs': 68, 'fat': 6}
      },
      {
        'id': 'local_filipino_snack_7',
        'title': 'Sapin-sapin',
        'description': 'Layered rice cake with different colors',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Rice flour', 'Coconut milk', 'Sugar', 'Food coloring'],
        'instructions': '1. In a bowl, mix rice flour, sugar, and coconut milk.\n2. Divide batter into 3 equal parts.\n3. Add different food coloring to each part (purple, yellow, white).\n4. Grease baking pan and line with banana leaves.\n5. Pour first colored layer and steam for 10 minutes.\n6. Add second layer and steam for 10 minutes.\n7. Add third layer and steam for 15 minutes.\n8. Let cool completely before cutting.\n9. Serve with grated coconut on top.',
        'nutrition': {'calories': 380, 'protein': 6, 'carbs': 68, 'fat': 8}
      },
      {
        'id': 'local_filipino_snack_8',
        'title': 'Buko Pandan',
        'description': 'Coconut and pandan jelly dessert',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Coconut', 'Pandan jelly', 'Evaporated milk', 'Condensed milk'],
        'instructions': '1. Prepare pandan jelly by mixing pandan extract with agar-agar.\n2. Let jelly set and cut into cubes.\n3. Grate fresh coconut and set aside.\n4. In a bowl, mix coconut with pandan jelly cubes.\n5. Add evaporated milk and condensed milk.\n6. Mix well and chill in refrigerator for 30 minutes.\n7. Serve cold in individual glasses.\n8. Garnish with more coconut on top.',
        'nutrition': {'calories': 320, 'protein': 4, 'carbs': 58, 'fat': 8}
      },
      {
        'id': 'local_filipino_snack_9',
        'title': 'Leche Flan',
        'description': 'Filipino caramel custard',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Eggs', 'Condensed milk', 'Evaporated milk', 'Sugar', 'Vanilla'],
        'instructions': '1. Make caramel by melting sugar in a pan until golden.\n2. Pour caramel into flan molds and swirl to coat bottom.\n3. In a bowl, whisk eggs, condensed milk, evaporated milk, and vanilla.\n4. Strain mixture to remove any lumps.\n5. Pour custard mixture over caramel in molds.\n6. Cover molds with foil and place in steamer.\n7. Steam for 30-40 minutes until set.\n8. Let cool completely before refrigerating.\n9. To serve, run knife around edges and invert onto plate.',
        'nutrition': {'calories': 280, 'protein': 8, 'carbs': 32, 'fat': 14}
      },
      {
        'id': 'local_filipino_snack_10',
        'title': 'Ube Halaya',
        'description': 'Purple yam jam dessert',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Purple yam', 'Coconut milk', 'Condensed milk', 'Butter', 'Sugar'],
        'instructions': '1. Boil purple yam until tender, then mash until smooth.\n2. In a pan, heat coconut milk and add mashed yam.\n3. Add condensed milk and sugar, mix well.\n4. Cook over low heat, stirring constantly.\n5. Add butter and continue cooking until thick.\n6. Stir frequently to prevent burning.\n7. Cook until mixture is thick and smooth.\n8. Let cool completely before serving.\n9. Serve with ice cream or as a spread on bread.',
        'nutrition': {'calories': 320, 'protein': 4, 'carbs': 68, 'fat': 8}
      },
      {
        'id': 'local_filipino_snack_11',
        'title': 'Polvoron',
        'description': 'Powdered milk candy',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Powdered milk', 'Flour', 'Sugar', 'Butter', 'Nuts'],
        'instructions': '1. Toast flour in a pan until golden brown.\n2. Let flour cool completely.\n3. In a bowl, mix toasted flour with powdered milk and sugar.\n4. Add melted butter and mix well.\n5. Add chopped nuts and mix until combined.\n6. Form mixture into small balls or use polvoron mold.\n7. Wrap each piece in cellophane or paper.\n8. Store in airtight container.\n9. Serve as a sweet treat or dessert.',
        'nutrition': {'calories': 180, 'protein': 4, 'carbs': 22, 'fat': 8}
      },
      {
        'id': 'local_filipino_snack_12',
        'title': 'Chicharon',
        'description': 'Crispy pork rinds',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Pork skin', 'Salt', 'Oil'],
        'instructions': '1. Clean pork skin and remove any excess fat.\n2. Cut into strips or squares.\n3. Season with salt and let sit for 30 minutes.\n4. Heat oil in a deep pan to 350°F (175°C).\n5. Carefully add pork skin pieces.\n6. Fry for 5-8 minutes until golden and crispy.\n7. Remove and drain on paper towels.\n8. Season with more salt if needed.\n9. Serve hot with vinegar dipping sauce.',
        'nutrition': {'calories': 520, 'protein': 28, 'carbs': 0, 'fat': 48}
      },
      
      // Filipino Soups & Stews
      {
        'id': 'local_filipino_soup_1',
        'title': 'Bulalo',
        'description': 'Beef bone marrow soup with vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Beef bones', 'Beef shank', 'Vegetables', 'Garlic', 'Onion', 'Fish sauce'],
        'instructions': '1. Boil beef bones and shank in water for 2-3 hours until tender.\n2. Skim off any foam that rises to the surface.\n3. Add garlic, onions, and peppercorns.\n4. Simmer for another 30 minutes.\n5. Add vegetables (corn, cabbage, potatoes) and cook for 15 minutes.\n6. Season with fish sauce, salt, and pepper to taste.\n7. Add leafy vegetables (kangkong or spinach) last.\n8. Simmer for 5 more minutes.\n9. Serve hot with steamed rice and fish sauce on the side.',
        'nutrition': {'calories': 480, 'protein': 35, 'carbs': 18, 'fat': 28}
      },
      {
        'id': 'local_filipino_soup_2',
        'title': 'Nilaga',
        'description': 'Boiled meat and vegetables soup',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Beef or pork', 'Vegetables', 'Garlic', 'Onion', 'Fish sauce'],
        'instructions': '1. Boil meat (beef or pork) in water for 1-2 hours until tender.\n2. Add garlic, onions, and peppercorns.\n3. Simmer for another 30 minutes.\n4. Add vegetables (potatoes, carrots, cabbage) and cook for 15 minutes.\n5. Add leafy vegetables (kangkong or spinach) last.\n6. Season with fish sauce, salt, and pepper to taste.\n7. Simmer for 5 more minutes.\n8. Serve hot with steamed rice and fish sauce on the side.',
        'nutrition': {'calories': 420, 'protein': 32, 'carbs': 22, 'fat': 22}
      },
      {
        'id': 'local_filipino_soup_3',
        'title': 'Pochero',
        'description': 'Beef stew with tomato sauce and vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Beef', 'Tomato sauce', 'Vegetables', 'Garlic', 'Onion', 'Bay leaves'],
        'instructions': '1. Cut beef into cubes and season with salt and pepper.\n2. Heat oil in a pot and brown the beef on all sides.\n3. Add garlic, onions, and tomatoes, sauté until soft.\n4. Add tomato sauce and water, bring to a boil.\n5. Reduce heat and simmer for 1-2 hours until beef is tender.\n6. Add vegetables (potatoes, carrots, green beans) and simmer for 15 minutes.\n7. Add bay leaves and peppercorns.\n8. Season with fish sauce, salt, and pepper to taste.\n9. Simmer for 10 more minutes and serve hot with steamed rice.',
        'nutrition': {'calories': 520, 'protein': 38, 'carbs': 28, 'fat': 28}
      },
      {
        'id': 'local_filipino_soup_4',
        'title': 'Batchoy',
        'description': 'Noodle soup with pork and liver',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Noodles', 'Pork', 'Liver', 'Garlic', 'Onion', 'Fish sauce'],
        'instructions': '1. Boil pork bones in water for 1-2 hours to make broth.\n2. Add garlic, onions, and peppercorns to broth.\n3. Simmer for another 30 minutes.\n4. Add pork meat and liver, cook until tender.\n5. Add noodles and cook for 5-7 minutes.\n6. Season with fish sauce, salt, and pepper to taste.\n7. Add leafy vegetables (kangkong or spinach) last.\n8. Simmer for 2-3 minutes.\n9. Serve hot with steamed rice and fish sauce on the side.',
        'nutrition': {'calories': 480, 'protein': 32, 'carbs': 42, 'fat': 22}
      },
      {
        'id': 'local_filipino_soup_5',
        'title': 'Pancit Malabon',
        'description': 'Thick rice noodles with seafood and vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Thick rice noodles', 'Seafood', 'Vegetables', 'Shrimp paste', 'Garlic'],
        'instructions': '1. Soak thick rice noodles in warm water for 10 minutes, then drain.\n2. Heat oil in a large wok or pan over high heat.\n3. Sauté garlic and onions until fragrant.\n4. Add seafood (shrimp, squid, fish) and cook until done.\n5. Add vegetables (carrots, cabbage, bell peppers) and stir-fry for 3-4 minutes.\n6. Add shrimp paste and mix well.\n7. Add the soaked noodles and toss everything together.\n8. Add a little water or broth if needed.\n9. Stir-fry for 5-7 minutes until noodles are tender.\n10. Season with fish sauce, salt, and pepper to taste.\n11. Garnish with green onions and serve hot.',
        'nutrition': {'calories': 520, 'protein': 28, 'carbs': 68, 'fat': 18}
      },
      {
        'id': 'local_filipino_soup_6',
        'title': 'Lomi',
        'description': 'Thick egg noodle soup with meat and vegetables',
        'image': null,
        'source': 'Local',
        'cuisine': 'Filipino',
        'ingredients': ['Thick egg noodles', 'Pork or chicken', 'Vegetables', 'Garlic', 'Onion'],
        'instructions': '1. Boil meat (pork or chicken) in water for 1-2 hours to make broth.\n2. Add garlic, onions, and peppercorns to broth.\n3. Simmer for another 30 minutes.\n4. Add thick egg noodles and cook for 5-7 minutes.\n5. Add vegetables (carrots, cabbage, green beans) and cook for 5 minutes.\n6. Season with fish sauce, salt, and pepper to taste.\n7. Add leafy vegetables (kangkong or spinach) last.\n8. Simmer for 2-3 minutes.\n9. Serve hot with steamed rice and fish sauce on the side.',
        'nutrition': {'calories': 480, 'protein': 25, 'carbs': 58, 'fat': 18}
      },
    ];

    // Filter recipes based on query
    if (query.isEmpty) return allFilipinoRecipes;
    
    final queryLower = query.toLowerCase();
    return allFilipinoRecipes.where((recipe) {
      final title = (recipe['title'] as String).toLowerCase();
      final description = (recipe['description'] as String).toLowerCase();
      return title.contains(queryLower) || description.contains(queryLower);
    }).toList();
  }

  /// Check if a dish name is Filipino
  static bool _isFilipinoDish(String dishName) {
    final filipinoKeywords = [
      'adobo', 'sinigang', 'kare-kare', 'lechon', 'pancit', 'sisig', 'bulalo',
      'nilaga', 'tinola', 'menudo', 'kaldereta', 'mechado', 'bicol express',
      'laing', 'pinakbet', 'ginataang', 'paksiw', 'batchoy', 'lomi',
      'halo-halo', 'bibingka', 'puto', 'kutsinta', 'sapin-sapin', 'buko pandan',
      'leche flan', 'ube', 'turon', 'lumpia', 'chicharon', 'polvoron',
      'tapsilog', 'tocino', 'longsilog', 'bangusilog', 'champorado', 'arroz caldo'
    ];
    
    return filipinoKeywords.any((keyword) => dishName.contains(keyword));
  }

  /// Extract ingredients from TheMealDB format
  static List<String> _extractMealDbIngredients(Map<String, dynamic> meal) {
    List<String> ingredients = [];
    for (int i = 1; i <= 20; i++) {
      final ingredient = meal['strIngredient$i'] as String?;
      final measure = meal['strMeasure$i'] as String?;
      if (ingredient != null && ingredient.isNotEmpty) {
        ingredients.add('${measure ?? ''} $ingredient'.trim());
      }
    }
    return ingredients;
  }

  /// Get recipe details by ID
  static Future<Map<String, dynamic>?> getRecipeDetails(String id) async {
    try {
      if (id.startsWith('themealdb_')) {
        return await _getTheMealDbRecipeDetails(id);
      } else if (id.startsWith('curated_') || id.startsWith('local_filipino_')) {
        return _getCuratedRecipeDetails(id);
      }
    } catch (e) {
      print('Error getting recipe details for $id: $e');
    }
    return null;
  }

  /// Get TheMealDB recipe details
  static Future<Map<String, dynamic>?> _getTheMealDbRecipeDetails(String id) async {
    try {
      final mealId = id.replaceFirst('themealdb_', '');
      final url = '$_themealdbUrl/lookup.php?i=$mealId';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final meals = data['meals'] as List<dynamic>? ?? [];
        if (meals.isNotEmpty) {
          final meal = meals.first;
          return {
            'id': id,
            'title': meal['strMeal'],
            'description': meal['strInstructions']?.substring(0, 200) ?? '',
            'image': meal['strMealThumb'],
            'source': 'TheMealDB',
            'cuisine': 'Filipino',
            'ingredients': _extractMealDbIngredients(meal),
            'instructions': meal['strInstructions'] ?? '',
            'sourceUrl': meal['strSource'],
            'nutrition': _generateEstimatedNutrition(meal),
            'category': meal['strCategory'] ?? 'Main Course',
          };
        }
      }
    } catch (e) {
      print('Error getting TheMealDB recipe details: $e');
    }
    return null;
  }


  /// Get curated recipe details
  static Map<String, dynamic>? _getCuratedRecipeDetails(String id) {
    final recipes = _getCuratedFilipinoRecipes('');
    return recipes.firstWhere(
      (recipe) => recipe['id'] == id,
      orElse: () => null,
    );
  }

  /// Generate estimated nutrition information for TheMealDB recipes
  static Map<String, dynamic> _generateEstimatedNutrition(Map<String, dynamic> meal) {
    // Generate estimated nutrition based on ingredients and meal type
    final ingredients = <String>[];
    for (int i = 1; i <= 20; i++) {
      final ingredient = meal['strIngredient$i'];
      if (ingredient != null && ingredient.trim().isNotEmpty) {
        ingredients.add(ingredient.trim().toLowerCase());
      }
    }
    
    // Base nutrition estimates for Filipino dishes
    double calories = 350.0;
    double protein = 18.0;
    double carbs = 35.0;
    double fat = 15.0;
    double fiber = 4.0;
    double sugar = 8.0;
    double sodium = 500.0;
    double cholesterol = 60.0;
    
    // Adjust based on ingredients
    for (final ingredient in ingredients) {
      if (ingredient.contains('meat') || ingredient.contains('chicken') || ingredient.contains('beef') || 
          ingredient.contains('pork') || ingredient.contains('fish') || ingredient.contains('lamb') ||
          ingredient.contains('bangus') || ingredient.contains('tuna') || ingredient.contains('shrimp')) {
        protein += 10.0;
        calories += 60.0;
        fat += 4.0;
        cholesterol += 25.0;
      }
      if (ingredient.contains('rice') || ingredient.contains('pasta') || ingredient.contains('bread') || 
          ingredient.contains('potato') || ingredient.contains('noodle') || ingredient.contains('pancit')) {
        carbs += 18.0;
        calories += 70.0;
        fiber += 1.5;
      }
      if (ingredient.contains('cheese') || ingredient.contains('milk') || ingredient.contains('cream') || 
          ingredient.contains('butter') || ingredient.contains('yogurt') || ingredient.contains('coconut milk')) {
        protein += 5.0;
        calories += 50.0;
        fat += 5.0;
        cholesterol += 18.0;
        sodium += 120.0;
      }
      if (ingredient.contains('vegetable') || ingredient.contains('tomato') || ingredient.contains('onion') || 
          ingredient.contains('carrot') || ingredient.contains('pepper') || ingredient.contains('lettuce') ||
          ingredient.contains('cabbage') || ingredient.contains('eggplant') || ingredient.contains('okra')) {
        fiber += 2.5;
        calories += 12.0;
        carbs += 4.0;
      }
      if (ingredient.contains('oil') || ingredient.contains('olive') || ingredient.contains('coconut') ||
          ingredient.contains('palm oil')) {
        fat += 10.0;
        calories += 80.0;
      }
      if (ingredient.contains('sugar') || ingredient.contains('honey') || ingredient.contains('syrup') ||
          ingredient.contains('brown sugar')) {
        sugar += 12.0;
        calories += 45.0;
        carbs += 12.0;
      }
      if (ingredient.contains('salt') || ingredient.contains('soy') || ingredient.contains('sauce') ||
          ingredient.contains('fish sauce') || ingredient.contains('shrimp paste')) {
        sodium += 250.0;
      }
      if (ingredient.contains('vinegar') || ingredient.contains('calamansi') || ingredient.contains('lemon')) {
        sodium += 50.0;
        calories += 5.0;
      }
    }
    
    // Adjust based on meal category
    final category = meal['strCategory']?.toString().toLowerCase() ?? '';
    if (category.contains('dessert') || category.contains('sweet') || category.contains('cake')) {
      calories += 120.0;
      sugar += 18.0;
      carbs += 25.0;
    } else if (category.contains('soup') || category.contains('stew') || category.contains('sinigang')) {
      calories -= 30.0;
      sodium += 400.0;
    } else if (category.contains('salad') || category.contains('vegetable')) {
      calories -= 80.0;
      fiber += 6.0;
    }
    
    return {
      'calories': calories.roundToDouble(),
      'protein': protein.roundToDouble(),
      'carbs': carbs.roundToDouble(),
      'fat': fat.roundToDouble(),
      'fiber': fiber.roundToDouble(),
      'sugar': sugar.roundToDouble(),
      'sodium': sodium.roundToDouble(),
      'cholesterol': cholesterol.roundToDouble(),
      'saturatedFat': (fat * 0.35).roundToDouble(),
      'transFat': 0.0,
      'monounsaturatedFat': (fat * 0.35).roundToDouble(),
      'polyunsaturatedFat': (fat * 0.30).roundToDouble(),
      'vitaminA': 600.0,
      'vitaminC': 35.0,
      'calcium': 250.0,
      'iron': 4.0,
      'potassium': 450.0,
      'magnesium': 60.0,
      'phosphorus': 180.0,
      'zinc': 2.5,
      'folate': 60.0,
      'vitaminD': 3.0,
      'vitaminE': 3.0,
      'vitaminK': 25.0,
      'thiamin': 0.6,
      'riboflavin': 0.4,
      'niacin': 5.0,
      'vitaminB6': 0.6,
      'vitaminB12': 1.2,
    };
  }

  /// Search for Filipino recipes by category
  static Future<List<dynamic>> searchByCategory(String category) async {
    final categoryMap = {
      'breakfast': ['tapsilog', 'tocino', 'longsilog', 'bangusilog', 'champorado', 'arroz caldo'],
      'lunch': ['adobo', 'sinigang', 'kare-kare', 'bicol express', 'laing', 'pinakbet'],
      'dinner': ['lechon', 'pancit', 'sisig', 'kaldereta', 'mechado', 'menudo'],
      'soup': ['bulalo', 'nilaga', 'tinola', 'batchoy', 'lomi'],
      'dessert': ['halo-halo', 'bibingka', 'puto', 'kutsinta', 'leche flan', 'ube'],
      'snack': ['lumpia', 'turon', 'chicharon', 'polvoron'],
    };

    final keywords = categoryMap[category.toLowerCase()] ?? [];
    List<dynamic> results = [];

    for (final keyword in keywords) {
      final recipes = await fetchFilipinoRecipes(keyword);
      results.addAll(recipes);
    }

    return results;
  }

  /// Get popular Filipino dishes
  static Future<List<dynamic>> getPopularFilipinoDishes() async {
    final popularDishes = [
      'adobo', 'sinigang', 'kare-kare', 'lechon kawali', 'pancit canton',
      'sisig', 'bulalo', 'halo-halo', 'lumpia', 'tapsilog'
    ];

    List<dynamic> results = [];
    for (final dish in popularDishes) {
      final recipes = await fetchFilipinoRecipes(dish);
      if (recipes.isNotEmpty) {
        results.add(recipes.first);
      }
    }

    return results;
  }
}
