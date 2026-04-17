import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MovieExplorerApp());
}

class MovieExplorerApp extends StatefulWidget {
  const MovieExplorerApp({super.key});

  @override
  State<MovieExplorerApp> createState() => _MovieExplorerAppState();
}

class _MovieExplorerAppState extends State<MovieExplorerApp> {
  final TextEditingController _searchController = TextEditingController();
  List<Movie> _movies = [];
  List<String> _favorites = [];
  bool _isLoading = false;
  String? _error;

  static const String omdbApiKey = 'e87ba178';
  static const String rapidApiKey = '9f1b4e5757msh9a7196e8dc1974fp16bed0jsnf99c4823a4cd';
  static const String rapidApiHost = 'imdb8.p.rapidapi.com';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _searchMovies(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _movies = [];
    });

    try {
      final url = Uri.parse('https://www.omdbapi.com/?apikey=$omdbApiKey&s=$query');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'True') {
          final List moviesJson = data['Search'];
          setState(() {
            _movies = moviesJson.map((json) => Movie.fromJson(json)).toList();
          });
        } else {
          setState(() {
            _error = data['Error'] ?? 'No movies found';
          });
        }
      } else {
        setState(() {
          _error = 'Failed to fetch data';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchTrendingMovies() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _movies = [];
    });

    final url = Uri.parse('https://imdb8.p.rapidapi.com/title/get-most-popular-movies');
    final response = await http.get(url, headers: {
      'X-RapidAPI-Key': rapidApiKey,
      'X-RapidAPI-Host': rapidApiHost,
    });

    if (response.statusCode == 200) {
      final List<dynamic> ids = json.decode(response.body);
      final List<Movie> trending = [];

      for (var id in ids.take(10)) {
        final cleanId = (id as String).split('/')[2];
        final detailUrl = Uri.parse(
          'https://imdb8.p.rapidapi.com/title/get-overview-details?tconst=$cleanId&currentCountry=US',
        );
        final detailResponse = await http.get(detailUrl, headers: {
          'X-RapidAPI-Key': rapidApiKey,
          'X-RapidAPI-Host': rapidApiHost,
        });

        if (detailResponse.statusCode == 200) {
          final detail = json.decode(detailResponse.body);
          final title = detail['title']['title'] ?? 'Unknown';
          final year = detail['title']['year']?.toString() ?? 'Unknown';
          final poster = detail['title']['image']?['url'] ?? 'N/A';
          final imdbID = cleanId;

          trending.add(Movie(title: title, year: year, poster: poster, imdbID: imdbID));
        }
      }

      setState(() {
        _movies = trending;
      });
    } else {
      setState(() {
        _error = 'Failed to load trending movies';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _showFavorites() async {
    if (_favorites.isEmpty) {
      setState(() {
        _movies = [];
        _error = 'No favorite movies yet';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _movies = [];
    });

    final List<Movie> favoriteMovies = [];

    for (final imdbID in _favorites) {
      final url = Uri.parse('https://www.omdbapi.com/?apikey=$omdbApiKey&i=$imdbID');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Response'] == 'True') {
          favoriteMovies.add(Movie.fromJson(data));
        }
      }
    }

    setState(() {
      _movies = favoriteMovies;
      _isLoading = false;
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites = prefs.getStringList('favorites') ?? [];
    });
  }

  Future<void> _toggleFavorite(String imdbID) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(imdbID)) {
        _favorites.remove(imdbID);
      } else {
        _favorites.add(imdbID);
      }
      prefs.setStringList('favorites', _favorites);
    });
  }

  bool _isFavorite(String imdbID) {
    return _favorites.contains(imdbID);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie Explorer',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: Scaffold(
        appBar: AppBar(title: const Text('Movie Explorer')),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Search movies...',
                      ),
                      onSubmitted: (value) => _searchMovies(value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _searchMovies(_searchController.text),
                    child: const Text('Search'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _fetchTrendingMovies,
                    child: const Text('Trending'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _showFavorites,
                    child: const Text('Favorites'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                )
              else if (_movies.isEmpty)
                  const Center(child: Text('No movies to display'))
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _movies.length,
                      itemBuilder: (context, index) {
                        final movie = _movies[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: movie.poster != 'N/A'
                                ? Image.network(
                              movie.poster,
                              width: 50,
                              fit: BoxFit.cover,
                            )
                                : const Icon(Icons.movie, size: 50),
                            title: Text(movie.title),
                            subtitle: Text(movie.year),
                            trailing: IconButton(
                              icon: Icon(
                                _isFavorite(movie.imdbID)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: Colors.red,
                              ),
                              onPressed: () => _toggleFavorite(movie.imdbID),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MovieDetailPage(imdbID: movie.imdbID),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class Movie {
  final String title;
  final String year;
  final String poster;
  final String imdbID;

  Movie({
    required this.title,
    required this.year,
    required this.poster,
    required this.imdbID,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      title: json['Title'] ?? json['title'] ?? 'Unknown',
      year: json['Year']?.toString() ?? json['year']?.toString() ?? 'Unknown',
      poster: json['Poster'] ?? json['poster'] ?? 'N/A',
      imdbID: json['imdbID'] ?? json['id'] ?? '',
    );
  }
}

class MovieDetailPage extends StatelessWidget {
  final String imdbID;

  static const String omdbApiKey = 'e87ba178';

  const MovieDetailPage({super.key, required this.imdbID});

  Future<Map<String, dynamic>?> fetchMovieDetail() async {
    final url = Uri.parse('https://www.omdbapi.com/?apikey=$omdbApiKey&i=$imdbID&plot=full');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['Response'] == 'True') {
        return data;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Movie Details")),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchMovieDetail(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Failed to load movie details.'));
          }

          final movie = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (movie['Poster'] != null && movie['Poster'] != 'N/A')
                  Center(
                    child: Image.network(movie['Poster'], height: 300),
                  ),
                const SizedBox(height: 16),
                Text(
                  movie['Title'] ?? 'Unknown Title',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("Year: ${movie['Year'] ?? 'Unknown'}"),
                Text("Genre: ${movie['Genre'] ?? 'N/A'}"),
                Text("Director: ${movie['Director'] ?? 'N/A'}"),
                const SizedBox(height: 12),
                Text(
                  "Plot:",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(movie['Plot'] ?? 'No plot available.'),
              ],
            ),
          );
        },
      ),
    );
  }
}
