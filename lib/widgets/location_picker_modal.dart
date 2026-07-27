import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';

/// 位置选择器模态框
class LocationPickerModal extends StatefulWidget {
  const LocationPickerModal({super.key});

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _favoriteLocations = [];
  bool _isSearching = false;
  bool _isLoadingCurrent = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 加载常用位置
  void _loadFavoriteLocations() {
    setState(() {
      _favoriteLocations = LocationService.getFavoriteLocations();
    });
  }

  /// 搜索位置
  Future<void> _searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await LocationService.searchLocations(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  /// 获取当前位置
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingCurrent = true;
    });

    final location = await LocationService.getCurrentLocation();
    if (location != null) {
      setState(() {
        _searchResults = [location];
        _isSearching = false;
        _isLoadingCurrent = false;
      });
    } else {
      setState(() {
        _isLoadingCurrent = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取当前位置')),
      );
    }
  }

  /// 选择位置
  void _selectLocation(Map<String, dynamic> location) {
    // 保存到常用位置
    LocationService.addOrUpdateLocation(
      id: location['id'],
      name: location['name'],
      latitude: location['latitude'],
      longitude: location['longitude'],
      address: location['address'],
    );

    // 返回选中的位置
    Navigator.pop(context, {
      'name': location['name'],
      'latitude': location['latitude'],
      'longitude': location['longitude'],
    });
  }

  /// 清除搜索
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 头部
        _buildHeader(context),
        const SizedBox(height: AppTheme.spaceLarge),

        // 搜索栏
        _buildSearchBar(context),
        const SizedBox(height: AppTheme.spaceLarge),

        // 内容区域
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLarge),
            child: _buildContent(context),
          ),
        ),

        // 底部安全区域
        const SizedBox(height: AppTheme.spaceLarge),
      ],
    );
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      child: Row(
        children: [
          const SizedBox(width: AppTheme.spaceLarge),
          Expanded(
            child: Text(
              '选择位置',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLarge),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.getSecondaryBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        child: Row(
          children: [
            const SizedBox(width: AppTheme.spaceMedium),
            Icon(Icons.search_rounded, color: AppTheme.neutral500, size: 20),
            const SizedBox(width: AppTheme.spaceSmall),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索位置...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _searchLocations,
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: _clearSearch,
                iconSize: 18,
              ),
            const SizedBox(width: AppTheme.spaceMedium),
          ],
        ),
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent(BuildContext context) {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchResults.isNotEmpty) {
      return _buildSearchResults(context);
    }

    return _buildDefaultContent(context);
  }

  /// 构建搜索结果
  Widget _buildSearchResults(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '搜索结果',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppTheme.spaceMedium),
        ..._searchResults.map((location) => _buildLocationItem(
              context,
              location,
              showAddress: true,
            )),
      ],
    );
  }

  /// 构建默认内容
  Widget _buildDefaultContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 当前位置按钮
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _getCurrentLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.getPrimaryColor(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spaceMedium,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                ),
                child: _isLoadingCurrent
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.my_location_rounded, size: 18),
                          SizedBox(width: AppTheme.spaceSmall),
                          Text('获取当前位置'),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXLarge),

        // 常用位置
        if (_favoriteLocations.isNotEmpty) ...[
          Text(
            '常用位置',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          ..._favoriteLocations.map((location) => _buildLocationItem(
                context,
                location,
                showAddress: true,
              )),
        ],

        // 推荐位置
        if (_favoriteLocations.isEmpty) ...[
          Text(
            '推荐位置',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spaceMedium),
          ...[
            {'id': 'rec1', 'name': '家', 'address': '常用位置', 'latitude': 0, 'longitude': 0},
            {'id': 'rec2', 'name': '公司', 'address': '常用位置', 'latitude': 0, 'longitude': 0},
            {'id': 'rec3', 'name': '商场', 'address': '常用位置', 'latitude': 0, 'longitude': 0},
            {'id': 'rec4', 'name': '餐厅', 'address': '常用位置', 'latitude': 0, 'longitude': 0},
            {'id': 'rec5', 'name': '超市', 'address': '常用位置', 'latitude': 0, 'longitude': 0},
          ].map((location) => _buildLocationItem(context, location)),
        ],
      ],
    );
  }

  /// 构建位置项
  Widget _buildLocationItem(
    BuildContext context,
    Map<String, dynamic> location, {
    bool showAddress = false,
  }) {
    return InkWell(
      onTap: () => _selectLocation(location),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spaceMedium,
          horizontal: AppTheme.spaceMedium,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.getPrimaryColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: AppTheme.getPrimaryColor(context),
                size: 18,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location['name'],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (showAddress && location['address'] != null)
                    Text(
                      location['address'],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.neutral500,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spaceMedium),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.neutral400,
            ),
          ],
        ),
      ),
    );
  }
}
