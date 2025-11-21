import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'catatan_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const MapScreen());
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<CatatanModel> _savedNotes = [];
  final MapController _mapController = MapController();
  final TextEditingController _noteController = TextEditingController(); 
  @override
  void initState() {
    super.initState();
    _loadNotes(); // Memanggil fungsi muat data
  }
  
  // fungsi dispose
  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
  IconData _getMarkerIcon(String type) {
    switch (type.toLowerCase()) {
      case 'rumah':
        return Icons.home;
      case 'kantor':
        return Icons.business;
      case 'toko':
        return Icons.store;
      default:
        return Icons.location_on;
    }
  }
  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = _savedNotes.map((n) => json.encode(n.toJson())).toList();
    await prefs.setStringList('saved_geo_notes', jsonList);
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList('saved_geo_notes');
    if (jsonList != null) {
      setState(() {
        _savedNotes.clear();
        _savedNotes.addAll(jsonList.map((jsonString) => CatatanModel.fromJson(json.decode(jsonString))));
      });
    }
  }


  Future<void> _findMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();

    _mapController.move(
      latlong.LatLng(position.latitude, position.longitude),
      15.0,
    );
  }

  void _showDeleteConfirmation(CatatanModel noteToDelete) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Hapus Catatan"),
          content: Text("Yakin ingin menghapus catatan di ${noteToDelete.address}?"),
          actions: [
            TextButton(
              child: const Text("Batal"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Hapus", style: TextStyle(color: Colors.red)),
              onPressed: () {
                setState(() {
                  _savedNotes.remove(noteToDelete);
                });
                _saveNotes();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleLongPress(latlong.LatLng point) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      point.latitude, 
      point.longitude
    );

    String address = placemarks.first.street ?? "Alamat tidak dikenal";
    _noteController.text = "";
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedType = 'rumah';
        return AlertDialog(
          title: Text("Buat Catatan di: ${address}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: "Tulis Catatan"),
              ),
              DropdownButtonFormField<String>(
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: 'rumah', child: Text('Rumah')),
                  DropdownMenuItem(value: 'kantor', child: Text('Kantor')),
                  DropdownMenuItem(value: 'toko', child: Text('Toko')),
                  DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
                ],
                onChanged: (String? newValue) {
                  selectedType = newValue;
                },
                decoration: const InputDecoration(labelText: "Pilih Tipe"),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Batal"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Simpan"),
              onPressed: () {
                if (_noteController.text.isNotEmpty) {
                  setState(() {
                    _savedNotes.add(CatatanModel(
                      position: point,
                      note: _noteController.text,
                      address: address,
                      type: selectedType ?? 'lainnya',
                    ));
                  });
                  _saveNotes();
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Geo-Catatan")),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const latlong.LatLng(-6.2, 106.8),
          initialZoom: 13.0,
          onLongPress: (tapPosition, point) => _handleLongPress(point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),

          MarkerLayer(
            markers: _savedNotes.map((n) => Marker(
              point: n.position,
              width: 50.0,
              height: 50.0,
              child: GestureDetector(
                onTap: () => _showDeleteConfirmation(n),
                child: Icon(
                  _getMarkerIcon(n.type),
                  color: Colors.red,
                  size: 35.0,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _findMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}