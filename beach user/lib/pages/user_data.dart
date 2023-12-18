import 'package:flutter/material.dart';

class UserData extends ChangeNotifier {
  String name = '';
  String email = '';
  String phoneNumber = '';
  String profileImageUrl = '';

  void updateUser(String newName, String newEmail, String newPhoneNumber,
      [String imageUrl = '']) {
    name = newName;
    email = newEmail;
    phoneNumber = newPhoneNumber;
    this.profileImageUrl = imageUrl;
    ;

    notifyListeners();
  }

 
}
