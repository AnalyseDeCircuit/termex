class GroupDto {
  final String id;
  final String name;
  final String color;
  final String icon;
  final String? parentId;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  const GroupDto({
    required this.id, required this.name, required this.color,
    required this.icon, this.parentId, required this.sortOrder,
    required this.createdAt, required this.updatedAt,
  });
}

class GroupInput {
  final String name;
  final String color;
  final String icon;
  final String? parentId;
  final int sortOrder;

  const GroupInput({
    required this.name, required this.color, required this.icon,
    this.parentId, required this.sortOrder,
  });
}
