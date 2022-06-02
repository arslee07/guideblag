import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class Location {
  final String title;
  final String description;
  final LatLng point;
  final Uri image;

  Location({
    required this.title,
    required this.description,
    required this.point,
    required this.image,
  });

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        title: json['title'],
        description: json['description'],
        point: LatLng(json['point'][0], json['point'][1]),
        image: Uri.parse(json['image']),
      );
}

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuideBlag',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const MainPage(),
    );
  }
}

Marker buildMarker({
  required LatLng point,
  required String title,
  required VoidCallback onPressed,
}) {
  return Marker(
    rotate: false,
    width: 64.0,
    height: 64.0,
    point: point,
    anchorPos: AnchorPos.align(AnchorAlign.top),
    builder: (context) {
      return IconButton(
        padding: EdgeInsets.zero,
        tooltip: title,
        icon: const Icon(
          Icons.place,
          color: Colors.red,
          size: 64,
        ),
        onPressed: onPressed,
      );
    },
  );
}

class MainPageController extends ChangeNotifier {
  AsyncValue<List<Location>> locations = const AsyncValue.loading();

  MainPageController() {
    fetch();
  }

  Future<void> fetch() async {
    locations = await AsyncValue.guard(() async {
      final res = await get(Uri.parse("https://raw.githubusercontent.com/arslee07/guideblag/master/data.json"));
      return [for (final e in jsonDecode(res.body)) Location.fromJson(e)];
    });
    notifyListeners();
  }
}

final mainPageControllerProvider =
    ChangeNotifierProvider((ref) => MainPageController());

class MainPage extends ConsumerWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(mainPageControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('GuideBlag')),
      body: controller.locations.when(
        data: (data) => FlutterMap(
          options: MapOptions(
            center: LatLng(50.2582925, 127.5327188),
            zoom: 15,
            minZoom: 13,
            maxZoom: 18.3,
          ),
          layers: [
            TileLayerOptions(
              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: ['a', 'b', 'c'],
            ),
            MarkerLayerOptions(
              markers: [
                for (final p in data)
                  buildMarker(
                    point: p.point,
                    title: p.title,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => LocationViewPage(p)),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
        error: (err, stack) => Center(child: Text(err.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class LocationViewPage extends StatelessWidget {
  final Location location;
  const LocationViewPage(this.location, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Информация")),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: Container(
                        height: double.infinity,
                        color: Colors.black12,
                        child: Image.network(
                          location.image.toString(),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.title,
                        style: Theme.of(context).textTheme.headline5,
                      ),
                      const SizedBox(height: 12),
                      Text(location.description),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                final lat = location.point.latitude.toString();
                final lng = location.point.longitude.toString();
                launchUrl(
                  Uri.parse("https://maps.google.com/maps?daddr=$lat,$lng"),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.map),
              label: const Text("Построить маршрут"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
