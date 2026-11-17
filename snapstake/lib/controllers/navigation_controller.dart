import 'package:get/get.dart';

class NavigationController extends GetxController {
  final RxInt selectedIndex = 0.obs;

  void onItemSelected(int index) {
    selectedIndex.value = index;

    // Handle navigation based on selected index
    switch (index) {
      case 0:
        // Home
        Get.offNamed('/home');
        break;
      case 1:
        // Create
        Get.offNamed('/create');
        break;
      case 2:
        // Explore
        print('Navigate to Explore');
        // Get.offNamed('/explore');
        break;
      case 3:
        // Profile
        Get.toNamed('/profile');
        break;
    }
  }

  void setCurrentIndex(int index) {
    selectedIndex.value = index;
  }
}
