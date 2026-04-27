import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductFilterModal extends StatefulWidget {
  final String? selectedCategory;
  final double? minPrice;
  final double? maxPrice;
  final String? sortBy;

  const ProductFilterModal({
    super.key,
    this.selectedCategory,
    this.minPrice,
    this.maxPrice,
    this.sortBy,
  });

  @override
  State<ProductFilterModal> createState() => _ProductFilterModalState();
}

class _ProductFilterModalState extends State<ProductFilterModal> {
  String? _selectedCategory;
  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'newest';

  final List<Map<String, String>> _categories = [
    {'name': 'All Categories', 'value': 'all'},
    {'name': 'Dresses & Skirts', 'value': 'dresses-skirts'},
    {'name': 'Tops & Blouses', 'value': 'tops-blouses'},
    {'name': 'Activewear', 'value': 'activewear-yoga'},
    {'name': 'Accessories', 'value': 'accessories'},
  ];

  final List<Map<String, String>> _sortOptions = [
    {'name': 'Newest First', 'value': 'newest'},
    {'name': 'Price: Low to High', 'value': 'price_asc'},
    {'name': 'Price: High to Low', 'value': 'price_desc'},
    {'name': 'Name: A to Z', 'value': 'name_asc'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _minPrice = widget.minPrice;
    _maxPrice = widget.maxPrice;
    _sortBy = widget.sortBy ?? 'newest';
  }

  void _applyFilters() {
    Navigator.pop(context, {
      'category': _selectedCategory,
      'minPrice': _minPrice,
      'maxPrice': _maxPrice,
      'sortBy': _sortBy,
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _minPrice = null;
      _maxPrice = null;
      _sortBy = 'newest';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategorySection(),
                  const SizedBox(height: 24),
                  _buildPriceSection(),
                  const SizedBox(height: 24),
                  _buildSortSection(),
                ],
              ),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Filters',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _clearFilters,
            child: Text('Clear All', style: GoogleFonts.goudyBookletter1911(color: Colors.red)),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._categories.map((category) {
          return RadioListTile<String>(
            value: category['value']!,
            groupValue: _selectedCategory,
            onChanged: (value) => setState(() => _selectedCategory = value),
            title: Text(category['name']!, style: GoogleFonts.goudyBookletter1911()),
            activeColor: Colors.black,
            contentPadding: EdgeInsets.zero,
          );
        }),
      ],
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Range',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Min Price',
                  labelStyle: GoogleFonts.goudyBookletter1911(),
                  prefixText: '₱',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _minPrice = double.tryParse(value);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Max Price',
                  labelStyle: GoogleFonts.goudyBookletter1911(),
                  prefixText: '₱',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _maxPrice = double.tryParse(value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSortSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sort By',
          style: GoogleFonts.goudyBookletter1911(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._sortOptions.map((option) {
          return RadioListTile<String>(
            value: option['value']!,
            groupValue: _sortBy,
            onChanged: (value) => setState(() => _sortBy = value!),
            title: Text(option['name']!, style: GoogleFonts.goudyBookletter1911()),
            activeColor: Colors.black,
            contentPadding: EdgeInsets.zero,
          );
        }),
      ],
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _applyFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Apply Filters',
              style: GoogleFonts.goudyBookletter1911(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
