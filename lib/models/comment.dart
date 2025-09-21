class Comment {
  final String species;
  final String personality;
  final String text;

  Comment({
    required this.species,
    required this.personality,
    required this.text,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      species: json['species'] ?? '',
      personality: json['personality'] ?? '',
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'species': species,
      'personality': personality,
      'text': text,
    };
  }
}
