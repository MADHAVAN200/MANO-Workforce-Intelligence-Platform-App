import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/auth_service.dart';
import '../../services/location_service.dart';
import '../../views/geofencing_screen.dart';

class GeoFencingView extends StatelessWidget {
  const GeoFencingView({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final service = LocationService(authService.dio);
    
    return Provider<LocationService>.value(
      value: service,
      child: GeofencingScreen(locationService: service),
    );
  }
}
