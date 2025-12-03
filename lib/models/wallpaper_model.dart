import 'package:cloud_firestore/cloud_firestore.dart';

class KWallpaper {
  final String id;
  final String userId;
  final String title;
  final String backgroundImage;
  final List<WidgetElement> elements;
  final DateTime createdAt;
  final bool isActive; 

  KWallpaper({
    required this.id,
    required this.userId,
    required this.title,
    required this.backgroundImage,
    required this.elements,
    required this.createdAt,
    this.isActive = false, 
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'backgroundImage': backgroundImage,
      'elements': elements.map((element) => element.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isActive': isActive, 
    };
  }

  factory KWallpaper.fromMap(Map<String, dynamic> map) {
    return KWallpaper(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      backgroundImage: map['backgroundImage'] ?? '',
      elements: List<WidgetElement>.from(
        (map['elements'] ?? []).map((element) => WidgetElement.fromMap(element)),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      isActive: map['isActive'] ?? false, 
    );
  }

  factory KWallpaper.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return KWallpaper(
      id: doc.id,
      userId: data['userId'],
      title: data['title'],
      backgroundImage: data['backgroundImage'],
      elements: [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt']),
    );
  }
  
  KWallpaper copyWith({bool? isActive}) {
    return KWallpaper(
      id: id,
      userId: userId,
      title: title,
      backgroundImage: backgroundImage,
      elements: elements,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class WidgetElement {
  String type; 
  String content;
  double x;
  double y;
  double scale;
  double rotation;
  Map<String, dynamic> style;

  WidgetElement({
    required this.type,
    required this.content,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.style = const {},
  });

  factory WidgetElement.fromMap(Map<String, dynamic> map) {
    return WidgetElement(
      type: map['type'],
      content: map['content'],
      x: map['x'].toDouble(),
      y: map['y'].toDouble(),
      scale: map['scale'].toDouble(),
      rotation: map['rotation'].toDouble(),
      style: Map<String, dynamic>.from(map['style']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'content': content,
      'x': x,
      'y': y,
      'scale': scale,
      'rotation': rotation,
      'style': style,
    };
  }
}