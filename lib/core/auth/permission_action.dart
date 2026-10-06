import 'package:flutter/material.dart';

enum PermissionAction {
  view('view', 'عرض', Icons.visibility_outlined),
  create('create', 'إضافة', Icons.add_circle_outline),
  edit('edit', 'تعديل', Icons.edit_outlined),
  delete('delete', 'حذف', Icons.delete_outline);

  const PermissionAction(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;

  static PermissionAction? parse(String? raw) {
    for (final PermissionAction action in PermissionAction.values) {
      if (action.id == raw) {
        return action;
      }
    }
    return null;
  }
}
