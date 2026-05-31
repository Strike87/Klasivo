import 'package:freezed_annotation/freezed_annotation.dart';

part 'class_model.freezed.dart';
part 'class_model.g.dart';

@freezed
class ClassModel with _$ClassModel {
  const factory ClassModel({
    required String id,
    required String teacherId,
    required String name,
    String? grade,
    required DateTime createdAt,
  }) = _ClassModel;

  factory ClassModel.fromJson(Map<String, dynamic> json) =>
      _$ClassModelFromJson(json);
}
