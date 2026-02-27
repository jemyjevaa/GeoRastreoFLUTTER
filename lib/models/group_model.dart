class GroupModel {
  final int id;
  final Map<String, dynamic> attributes;
  final int groupId;
  final String name;

  GroupModel({
    required this.id,
    required this.attributes,
    required this.groupId,
    required this.name,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] as int,
      attributes: json['attributes'] as Map<String, dynamic>? ?? {},
      groupId: json['groupId'] as int? ?? 0,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'attributes': attributes,
      'groupId': groupId,
      'name': name,
    };
  }
}
