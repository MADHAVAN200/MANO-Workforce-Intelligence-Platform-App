import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_success_dialog.dart';
import '../../../../shared/widgets/glass_confirmation_dialog.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

class GeofencingScreen extends StatefulWidget {
  final LocationService locationService;
  const GeofencingScreen({Key? key, required this.locationService}) : super(key: key);

  @override
  _GeofencingScreenState createState() => _GeofencingScreenState();
}

class _GeofencingScreenState extends State<GeofencingScreen> {
  // Locations State
  List<WorkLocation> _locations = [];
  WorkLocation? _selectedLocation;
  double _currentRadius = 100.0;
  bool _isLoading = true;

  // Users State
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _fetchUsers();
  }

  // --- API FETCHING ---

  Future<void> _fetchLocations() async {
    try {
      final data = await widget.locationService.getLocations();
      if (mounted) {
        setState(() {
          _locations = data;
          _isLoading = false;
          // Select first if none selected
          if (data.isNotEmpty && _selectedLocation == null) {
            _selectLocation(data.first);
          } else if (_selectedLocation != null) {
             // Refresh selected object
             final updated = data.firstWhere((l) => l.id == _selectedLocation!.id, orElse: () => data.first);
             _selectLocation(updated);
          }
        });
      }
    } catch (e) {
      print(e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await widget.locationService.getUsersWithLocations();
      debugPrint("Fetched ${users.length} users");
      // Debug first user structure
      if (users.isNotEmpty) {
        print("User 0: ${users.first}");
      }
      if (mounted) {
        setState(() {
          _users = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      print("Failed to fetch users: $e");
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  // --- ACTIONS ---

  void _selectLocation(WorkLocation loc) {
    setState(() {
      _selectedLocation = loc;
      _currentRadius = loc.radius.toDouble();
    });
  }

  void _updateRadius(double newRadius) {
     if (_selectedLocation == null) return;
     
     // Optimistic UI Update not easily possible for immutable object without deep copy/copyWith
     // We will just call API and refresh.
     // To make slider smooth, we might need local state for slider value if we wanted "live" sliding.
     // But `onChangeEnd` is safe.

     widget.locationService.updateLocation(_selectedLocation!.id, {"radius": newRadius.toInt()}).then((_) {
         _fetchLocations(); 
     });
  }

  Future<void> _toggleActiveStatus() async {
    if (_selectedLocation == null) return;
    final newStatus = !_selectedLocation!.isActive;
    
    try {
      await widget.locationService.updateLocation(_selectedLocation!.id, {"is_active": newStatus ? 1 : 0});
      _fetchLocations();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e")));
    }
  }



  Future<void> _toggleUserAssignment(int userId, String userName, bool isAssigned) async {
      if (_selectedLocation == null) return;
      
      final isAdding = !isAssigned;
      final action = isAdding ? "assign" : "remove";
      final preposition = isAdding ? "to" : "from";

      // 1. Confirmation Dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => GlassConfirmationDialog(
          title: isAdding ? "Confirm Assignment" : "Confirm Removal",
          content: "Are you sure you want to $action $userName $preposition ${_selectedLocation!.name}?",
          confirmLabel: isAdding ? "Assign" : "Remove",
          onConfirm: () => Navigator.pop(context, true),
        ),
      );

      if (confirm != true) return;

      // 2. Perform Action
      try {
        await widget.locationService.assignUser(_selectedLocation!.id, userId, isAdding);
        _fetchUsers(); 

        if (!mounted) return;

        // 3. Success Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => GlassSuccessDialog(
            title: isAdding ? "User Assigned" : "User Removed",
            message: "$userName has been successfully ${isAdding ? "assigned to" : "removed from"} ${_selectedLocation!.name}.",
            onDismiss: () => Navigator.pop(context),
          ),
        );

      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Assignment failed: $e")));
      }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _LocationFormDialog(
        onSubmit: (data) async {
          try {
            await widget.locationService.createLocation(data);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            _fetchLocations();
            if (!mounted) return;
            
            // Success Dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => GlassSuccessDialog(
                title: "Location Created",
                message: "New geofence location has been successfully created.",
                onDismiss: () => Navigator.pop(context),
              ),
            );
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
        },
      ),
    );
  }

  // --- LAYOUT BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return _buildDesktopLayout();
          }
          return _buildMobileLayout();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. LEFT PANEL: Locations List (320px)
          SizedBox(
            width: 320,
            child: GlassContainer(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: 12,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                   _buildListHeader(),
                   const Divider(height: 1),
                   Expanded(child: _buildLocationList()),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 2. CENTER PANEL: Location Details (Flexible)
          Expanded(
            flex: 2,
            child: GlassContainer(
               color: isDark ? const Color(0xFF161B22) : Colors.white,
               borderRadius: 12,
               padding: const EdgeInsets.all(24),
               child: _selectedLocation == null 
                  ? const Center(child: Text("Select a location to edit", style: TextStyle(color: Colors.grey)))
                  : _buildLocationSettingsPanel(isDark),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 3. RIGHT PANEL: Assigned Staff (320px)
          SizedBox(
            width: 320,
            child: GlassContainer(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: 12,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                   Padding(
                     padding: const EdgeInsets.all(16),
                     child: Row(
                       children: [
                         const Icon(Icons.people_outline, size: 20),
                         const SizedBox(width: 8),
                         Text("Assigned Staff", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                       ],
                     ),
                   ),
                   const Divider(height: 1),
                   Expanded(child: _buildStaffList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSettingsPanel(bool isDark) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      Text(_selectedLocation!.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 4),
                      Text(_selectedLocation!.address, style: const TextStyle(color: Colors.grey)),
                   ],
                 ),
               ),
               const SizedBox(width: 8),
               Switch(
                  value: _selectedLocation!.isActive, 
                  onChanged: (_) => _toggleActiveStatus(),
                   activeTrackColor: Colors.indigo,
               ),
             ],
           ),
           const SizedBox(height: 32),
           
           // Radius Slider
           Text("Geofence Radius", style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
           const SizedBox(height: 8),
           Row(
             children: [
               Expanded(
                 child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                       trackHeight: 6,
                       activeTrackColor: Colors.indigo,
                       thumbColor: Colors.indigo,
                       overlayColor: Colors.indigo.withValues(alpha: 0.2),
                    ),
                     child: Slider(
                      value: _currentRadius.clamp(0, 2000), 
                      min: 0, 
                      max: 2000,
                      onChanged: (val) {
                        setState(() => _currentRadius = val);
                      },
                      onChangeEnd: (val) => _updateRadius(val),
                   ),
                 ),
               ),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                   color: Colors.indigo.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(8)
                 ),
                 child: Text("${_currentRadius.toInt()} m", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
               )
             ],
           ),
           
           const SizedBox(height: 32),
           
           // Coordinates (Read Only / Editable could be added)
           Text("Coordinates", style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
           const SizedBox(height: 16),
           Row(
             children: [
                Expanded(
                  child: _buildInfoCard(isDark, "Latitude", _selectedLocation!.latitude.toString()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoCard(isDark, "Longitude", _selectedLocation!.longitude.toString()),
                ),
             ],
           ),
        ],
      );
  }


  
  Widget _buildInfoCard(bool isDark, String label, String value) {
     return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!)
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
         ],
       ),
     );
  }

  Widget _buildMobileLayout() {
     return _buildLocationList(isMobile: true);
  }

  // --- SUB-WIDGETS ---

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Text("Locations", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
           const SizedBox(height: 10),
           TextField(
             decoration: InputDecoration(
               hintText: "Search offices...",
               prefixIcon: const Icon(Icons.search, size: 18),
               filled: true,
               fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey[100],
               border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
               contentPadding: const EdgeInsets.symmetric(vertical: 8)
             ),
           )
        ],
      ),
    );
  }

  Widget _buildLocationList({bool isMobile = false}) {
     if (_isLoading) return const Center(child: CircularProgressIndicator());
     
     return ListView.separated(
       padding: const EdgeInsets.all(12),
       itemCount: _locations.length,
       separatorBuilder: (context, index) => const SizedBox(height: 8),
       itemBuilder: (context, index) {
         final loc = _locations[index];
         final isSelected = loc.id == _selectedLocation?.id;
         final isDark = Theme.of(context).brightness == Brightness.dark;
         
         // Count active users
         final activeUsers = _users.where((u) {
            final List<dynamic>? userLocs = u['work_locations'];
            if (userLocs == null) return false;
            return userLocs.any((l) => l is Map && (l['location_id'] == loc.id || l['loc_id'] == loc.id));
         }).length;

         return InkWell(
           onTap: () {
              _selectLocation(loc);
              if (isMobile) {
                _showMobileDetailSheet(loc);
              }
           },
           child: Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: isSelected && !isMobile
                  ? (isDark ? Colors.indigo.withValues(alpha: 0.2) : Colors.indigo[50])
                  : (isDark ? const Color(0xFF161B22) : Colors.white),
               borderRadius: BorderRadius.circular(8),
               border: isSelected && !isMobile ? Border.all(color: Colors.indigo.withValues(alpha: 0.5)) : null,
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(loc.name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected && !isMobile ? Colors.indigo : null)),
                     Container(
                       width: 8, height: 8,
                       decoration: BoxDecoration(
                         color: loc.isActive ? Colors.green : Colors.grey,
                         shape: BoxShape.circle,
                       ),
                     )
                   ],
                 ),
                 const SizedBox(height: 4),
                 Text(loc.address, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1),
               ],
             ),
           ),
         );
       },
     );
  }

  Widget _buildStaffList({WorkLocation? location}) {
    final targetLocation = location ?? _selectedLocation;

    if (targetLocation == null) {
      return const Center(child: Text("Select a location", style: TextStyle(color: Colors.grey)));
    }
    if (_isLoadingUsers) return const Center(child: CircularProgressIndicator());
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        // Keys based on React implementation
        final name = user['user_name'] ?? 'Unknown'; 
        final role = user['desg_name'] ?? 'Staff';
        final int userId = user['user_id'] ?? 0;
        
        // Check assignment
        final List<dynamic>? userLocs = user['work_locations'];
        bool isAssigned = false;
        if (userLocs != null) {
           isAssigned = userLocs.any((l) => l is Map && (l['location_id'] == targetLocation.id || l['loc_id'] == targetLocation.id));
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.indigo[100],
                child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(role, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(isAssigned ? Icons.check_circle : Icons.add_circle_outline),
                color: isAssigned ? Colors.green : Colors.grey,
                onPressed: () => _toggleUserAssignment(userId, name, isAssigned),
              )
            ],
          ),
        );
      },
    );
  }
  
  void _showMobileDetailSheet(WorkLocation loc) {
      showModalBottomSheet(
        context: context, 
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
          ),
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
               // Header
               Padding(
                 padding: const EdgeInsets.all(16),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(loc.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                           Text("Assign Staff", style: TextStyle(fontSize: 13, color: Colors.indigo.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                         ],
                       ),
                     ),
                     IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
                   ],
                 ),
               ),
               const Divider(),
               Expanded(
                 child: _buildStaffList(location: loc),
               )
            ],
          ),
        )
      );
  }

}

class _LocationFormDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  const _LocationFormDialog({required this.onSubmit});

  @override
  __LocationFormDialogState createState() => __LocationFormDialogState();
}

class __LocationFormDialogState extends State<_LocationFormDialog> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  double _radius = 100;

  @override
  Widget build(BuildContext context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      
      // Theme Colors
      final glassColor = isDark ? const Color(0xFF161B22) : Colors.white;
      final textColor = isDark ? Colors.white : Colors.black87;
      final hintColor = isDark ? Colors.white54 : Colors.grey;

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: GlassContainer(
              color: glassColor,
              borderRadius: 24,
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("New Geofence", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                        IconButton(icon: Icon(Icons.close, color: hintColor), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Form Fields
                    _GlassTextField(controller: _nameCtrl, label: "Location Name", icon: Icons.business, isDark: isDark),
                    const SizedBox(height: 16),
                    _GlassTextField(controller: _addressCtrl, label: "Address", icon: Icons.map, isDark: isDark),
                    const SizedBox(height: 16),
                    
                    LayoutBuilder(
                      builder: (context, constraints) {
                         if (constraints.maxWidth > 400) {
                           // Side by Side
                           return Row(
                             children: [
                               Expanded(child: _GlassTextField(controller: _latCtrl, label: "Latitude", icon: Icons.gps_fixed, isNumeric: true, isDark: isDark)),
                               const SizedBox(width: 16),
                               Expanded(child: _GlassTextField(controller: _lngCtrl, label: "Longitude", icon: Icons.gps_fixed, isNumeric: true, isDark: isDark)),
                             ],
                           );
                         }
                         return Column(
                           children: [
                              _GlassTextField(controller: _latCtrl, label: "Latitude", icon: Icons.gps_fixed, isNumeric: true, isDark: isDark),
                              const SizedBox(height: 16),
                              _GlassTextField(controller: _lngCtrl, label: "Longitude", icon: Icons.gps_fixed, isNumeric: true, isDark: isDark),
                           ],
                         );
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Radius Slider
                    Text("Radius: ${_radius.toInt()} meters", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: Colors.indigo,
                        inactiveTrackColor: isDark ? Colors.white24 : Colors.grey[300],
                        thumbColor: Colors.white,
                        overlayColor: Colors.indigo.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _radius, 
                        min: 0, 
                        max: 2000, 
                        onChanged: (v) => setState(() => _radius = v)
                      ),
                    ),

                    const SizedBox(height: 32),
                    
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                           if (_nameCtrl.text.isEmpty || _latCtrl.text.isEmpty) return;
                           widget.onSubmit({
                              "location_name": _nameCtrl.text,
                              "address": _addressCtrl.text,
                              "latitude": double.tryParse(_latCtrl.text) ?? 0.0,
                              "longitude": double.tryParse(_lngCtrl.text) ?? 0.0,
                              "radius": _radius.toInt()
                           });
                        },
                        child: const Text("Create Location", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
          ),
        ),
      );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isNumeric;
  final bool isDark;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.isNumeric = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.grey),
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
