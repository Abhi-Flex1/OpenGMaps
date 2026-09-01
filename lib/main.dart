import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'src/harmony/harmony_theme.dart';
import 'src/harmony/harmony_colors.dart';
import 'src/harmony/widgets/hmos_card.dart';
import 'src/harmony/widgets/hmos_search_bar.dart';
import 'src/harmony/widgets/hmos_button.dart';
import 'src/harmony/widgets/hmos_chip.dart';
import 'src/harmony/widgets/hmos_list_tile.dart';
import 'src/harmony/widgets/hmos_bottom_sheet.dart';
import 'src/maps/open_gmaps_types.dart';
import 'src/maps/open_gmaps_widget.dart';
import 'src/maps/open_gmaps_controller.dart';

void main() {
  runApp(const OpenGMapsApp());
}

class OpenGMapsApp extends StatelessWidget {
  const OpenGMapsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenGMaps',
      debugShowCheckedModeBanner: false,
      theme: HmosTheme.light(),
      darkTheme: HmosTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

// Demo place model
class Place {
  const Place({required this.name, required this.address, required this.latLng, required this.category, this.rating = 4.5, this.image = ''});
  final String name;
  final String address;
  final OpenLatLng latLng;
  final String category;
  final double rating;
  final String image;
}

const _places = [
  Place(name: 'Forbidden City', address: '4 Jingshan Front St, Dongcheng', latLng: OpenLatLng(39.9163, 116.3972), category: 'Culture'),
  Place(name: 'The Bund', address: 'Zhongshan East 1st Rd, Huangpu', latLng: OpenLatLng(31.2304, 121.5075), category: 'Sights'),
  Place(name: 'Victoria Harbour', address: 'Tsim Sha Tsui, Hong Kong', latLng: OpenLatLng(22.2943, 114.1722), category: 'Sights'),
  Place(name: 'Shenzhen Bay Park', address: 'Nanshan District, Shenzhen', latLng: OpenLatLng(22.5220, 113.9350), category: 'Nature'),
  Place(name: 'Guangzhou Tower', address: 'Yuejiang West Rd, Haizhu', latLng: OpenLatLng(23.1060, 113.3247), category: 'Sights'),
  Place(name: 'West Lake', address: 'Xihu District, Hangzhou', latLng: OpenLatLng(30.2590, 120.1388), category: 'Nature'),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  OpenGMapsController? _mapController;
  OpenMapType _mapType = OpenMapType.normal;
  int _selectedChip = 0;
  int _navIndex = 0;
  String _query = '';
  OpenLatLng? _selectedPlace;
  final _sheetController = DraggableScrollableController();

  final _filters = const [
    HmosFilter('All', Icons.explore_outlined),
    HmosFilter('Food', Icons.restaurant_outlined),
    HmosFilter('Hotels', Icons.hotel_outlined),
    HmosFilter('Sights', Icons.photo_camera_outlined),
    HmosFilter('Nature', Icons.park_outlined),
  ];

  OpenCameraPosition get _initialCamera => const OpenCameraPosition(target: OpenLatLng(31.2304, 121.4737), zoom: 5);

  List<Place> get _filteredPlaces {
    if (_query.isEmpty && _selectedChip == 0) return _places;
    return _places.where((p) {
      final matchesQuery = _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase()) || p.address.toLowerCase().contains(_query.toLowerCase());
      final matchesChip = _selectedChip == 0 || p.category == _filters[_selectedChip].label;
      return matchesQuery && matchesChip;
    }).toList();
  }

  Set<OpenMarker> get _markers => _filteredPlaces
      .map((p) => OpenMarker(
            markerId: p.name,
            position: p.latLng,
            title: p.name,
            snippet: p.address,
            onTap: () => _onPlaceTap(p),
          ))
      .toSet();

  void _onPlaceTap(Place p) {
    setState(() => _selectedPlace = p.latLng);
    _mapController?.animateCamera(OpenCameraPosition(target: p.latLng, zoom: 14));
    _sheetController.animateTo(0.35, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _onMapTap(OpenLatLng ll) {
    setState(() => _selectedPlace = ll);
  }

  void _showMapTypeSheet() {
    showHmosBottomSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Map type', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...OpenMapType.values.map((t) => HmosListTile(
                  title: t.label,
                  leading: Icon(t.icon, color: _mapType == t ? HmosColors.primary : HmosColors.textSecondary),
                  trailing: _mapType == t ? const Icon(Icons.check, color: HmosColors.primary) : null,
                  onTap: () {
                    setState(() => _mapType = t);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 12),
            Text(
              'On OpenHarmony, tiles are rendered via pure-Dart OSM/Google tiles. On Android/iOS, native Google Maps SDK is used.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceSheet(Place p) {
    showHmosBottomSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: HmosColors.primaryContainer, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.place, color: HmosColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                      Text(p.address, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: HmosColors.primaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.star, size: 14, color: HmosColors.primary),
                    const SizedBox(width: 4),
                    Text('${p.rating}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: HmosColors.primary)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: HmosButton(label: 'Directions', icon: Icons.directions_outlined, onPressed: () => Navigator.pop(context))),
                const SizedBox(width: 12),
                Expanded(child: HmosButton(label: 'Start', variant: HmosButtonVariant.secondary, icon: Icons.navigation, onPressed: () {})),
              ],
            ),
            const SizedBox(height: 12),
            HmosButton(label: 'Share location', variant: HmosButtonVariant.ghost, icon: Icons.share_outlined, onPressed: () {}, fullWidth: true),
          ],
        ),
      ),
    );
  }

  bool get _isOhos => !kIsWeb && defaultTargetPlatform.toString().contains('ohos');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          // Map
          Positioned.fill(
            child: OpenGMaps(
              initialPosition: _initialCamera,
              markers: _markers,
              mapType: _mapType,
              onMapCreated: (c) => _mapController = c,
              onTap: _onMapTap,
              onCameraMove: (pos) {},
            ),
          ),

          // Top blur/scrim
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(isDark ? 0.0 : 0.85), Colors.white.withOpacity(0.0)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: HmosSearchCard(
                        child: HmosSearchBar(
                          controller: _searchCtrl,
                          hintText: 'Search places, food, hotels',
                          focusNode: _searchFocus,
                          onChanged: (v) => setState(() => _query = v),
                          onClear: () => setState(() {
                            _searchCtrl.clear();
                            _query = '';
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filters
                    HmosFilterChips(
                      filters: _filters,
                      selected: _selectedChip,
                      onSelect: (i) => setState(() => _selectedChip = i),
                    ),
                    const SizedBox(height: 8),
                    // OHOS badge
                    if (_isOhos)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: HmosColors.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: HmosColors.primary.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: HmosColors.primary, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('OpenHarmony backport — tile fallback', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: HmosColors.primary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Right side controls
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.32,
            child: Column(
              children: [
                HmosIconButton(icon: Icons.layers_outlined, onPressed: _showMapTypeSheet),
                const SizedBox(height: 12),
                HmosIconButton(icon: Icons.my_location, onPressed: () => _mapController?.animateCamera(const OpenCameraPosition(target: OpenLatLng(39.9163, 116.3972), zoom: 12))),
                const SizedBox(height: 12),
                HmosIconButton(icon: Icons.add, onPressed: () {}),
                const SizedBox(height: 8),
                HmosIconButton(icon: Icons.remove, onPressed: () {}),
              ],
            ),
          ),

          // Bottom sheet
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.32,
            minChildSize: 0.12,
            maxChildSize: 0.78,
            snap: true,
            snapSizes: const [0.12, 0.32, 0.78],
            builder: (context, scrollController) {
              final places = _filteredPlaces;
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor == HmosColors.background ? HmosColors.surface : HmosColors.darkSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, -4))],
                ),
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(width: 36, height: 4, decoration: BoxDecoration(color: HmosColors.dividerStrong, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text('${places.length} places', style: Theme.of(context).textTheme.titleSmall),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {},
                                  child: Text('See all', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: HmosColors.primary)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                        final p = places[i];
                        final isSelected = _selectedPlace == p.latLng;
                        return Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: HmosCard(
                            padding: const EdgeInsets.all(12),
                            onTap: () => _showPlaceSheet(p),
                            elevated: isSelected,
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    color: HmosColors.surfaceVariant,
                                    child: const Icon(Icons.photo, color: HmosColors.textTertiary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(p.address, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: HmosColors.primaryContainer, borderRadius: BorderRadius.circular(6)),
                                            child: Text(p.category, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: HmosColors.primary)),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.star, size: 12, color: Colors.amber),
                                          const SizedBox(width: 2),
                                          Text('${p.rating}', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11)),
                                          const Spacer(),
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: const BoxDecoration(color: HmosColors.primary, shape: BoxShape.circle),
                                            child: const Icon(Icons.directions, size: 16, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                        childCount: places.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              );
            },
          ),

          // Bottom bar (floating) — HarmonyOS pill
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: HmosColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
        border: Border.all(color: HmosColors.divider.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.map_outlined, Icons.map, 'Explore'),
          _navItem(1, Icons.bookmark_border, Icons.bookmark, 'Saved'),
          _navItem(2, Icons.person_outline, Icons.person, 'You'),
        ],
      ),
    );
  }

  Widget _navItem(int idx, IconData outline, IconData filled, String label) {
    final selected = idx == _navIndex;
    return GestureDetector(
      onTap: () => setState(() => _navIndex = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? HmosColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(selected ? filled : outline, size: 22, color: selected ? HmosColors.primary : HmosColors.textTertiary),
            if (selected) ...[
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: HmosColors.primary, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
