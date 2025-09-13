import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'recipe_detail_page.dart';

class MealFavoritesPage extends StatefulWidget {
  const MealFavoritesPage({super.key});

  @override
  State<MealFavoritesPage> createState() => _MealFavoritesPageState();
}

class _MealFavoritesPageState extends State<MealFavoritesPage> {
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final favoritesQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();

      setState(() {
        _favorites = favoritesQuery.docs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(docId)
          .delete();

      setState(() {
        _favorites.removeWhere((favorite) => favorite['docId'] == docId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from favorites'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing favorite: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rateRecipe(Map<String, dynamic> recipe, double rating) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docId = recipe['docId'];
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(docId)
          .update({
        'rating': rating,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        final index = _favorites.indexWhere((fav) => fav['docId'] == docId);
        if (index != -1) {
          _favorites[index]['rating'] = rating;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rated ${rating.toStringAsFixed(1)} stars'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rating recipe: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Meals'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFavorites,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _favorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No favorite meals yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start adding meals to your favorites!',
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _favorites.length,
                      itemBuilder: (context, index) {
                        final favorite = _favorites[index];
                        return _buildFavoriteCard(favorite);
                      },
                    ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> favorite) {
    final recipe = favorite['recipe'] as Map<String, dynamic>? ?? {};
    final rating = favorite['rating']?.toDouble();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailPage(recipe: recipe),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: recipe['image'] != null && recipe['image'].toString().isNotEmpty
                  ? Image.network(
                      recipe['image'],
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 160,
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.green),
                          ),
                        );
                      },
                    )
                  : _buildPlaceholderImage(),
            ),

            // Recipe Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe['title'] ?? 'Unknown Recipe',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeFavorite(favorite['docId']),
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        tooltip: 'Remove from favorites',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Rating Section
                  Row(
                    children: [
                      const Text('Rate this recipe: '),
                      ...List.generate(5, (starIndex) {
                        return GestureDetector(
                          onTap: () => _rateRecipe(favorite, starIndex + 1.0),
                          child: Icon(
                            starIndex < (rating ?? 0) ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 24,
                          ),
                        );
                      }),
                      if (rating != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Recipe Stats
                  Row(
                    children: [
                      if (recipe['readyInMinutes'] != null) ...[
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe['readyInMinutes']} min',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (recipe['servings'] != null) ...[
                        Icon(Icons.people, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe['servings']} servings',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                  
                  if (favorite['notes'] != null && favorite['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.note, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              favorite['notes'],
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 48,
              color: Colors.green,
            ),
            SizedBox(height: 8),
            Text(
              'Recipe Image',
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to add recipes to favorites (to be used in other pages)
class FavoriteService {
  static Future<void> addToFavorites(
    BuildContext context,
    Map<String, dynamic> recipe, {
    String? notes,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if already favorited
      final existingQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .where('recipe.id', isEqualTo: recipe['id'])
          .get();

      if (existingQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe is already in favorites'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .add({
        'recipe': recipe,
        'notes': notes,
        'addedAt': FieldValue.serverTimestamp(),
        'rating': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to favorites!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to favorites: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<bool> isFavorited(String recipeId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .where('recipe.id', isEqualTo: recipeId)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<void> removeFromFavorites(String recipeId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .where('recipe.id', isEqualTo: recipeId)
          .get();

      for (final doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Handle error silently
    }
  }
}
