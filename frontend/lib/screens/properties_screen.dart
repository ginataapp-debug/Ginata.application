import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/ginata_theme.dart';
import '../services/api_service.dart';
import 'manual_booking_dialog.dart';

class PropertiesScreen extends StatefulWidget {
  final VoidCallback? onNewBooking;

  const PropertiesScreen({super.key, this.onNewBooking});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  List<dynamic> _properties = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() => _isLoading = true);
    final props = await ApiService.fetchProperties();
    if (!mounted) return;
    setState(() {
      _properties = props;
      _isLoading = false;
    });
  }

  List<dynamic> get _filteredProperties {
    if (_searchQuery.trim().isEmpty) return _properties;
    final q = _searchQuery.toLowerCase();
    return _properties.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final city = (p['city'] ?? '').toString().toLowerCase();
      final country = (p['country'] ?? '').toString().toLowerCase();
      return name.contains(q) || city.contains(q) || country.contains(q);
    }).toList();
  }

  void _openPropertyDialog({Map<String, dynamic>? property}) async {
    final isEditing = property != null;
    final nameCtrl = TextEditingController(text: property?['name']?.toString() ?? '');
    final addressCtrl = TextEditingController(text: property?['address']?.toString() ?? '');
    final cityCtrl = TextEditingController(text: property?['city']?.toString() ?? 'Nairobi');
    final countryCtrl = TextEditingController(text: property?['country']?.toString() ?? 'Kenya');
    final rateCtrl = TextEditingController(text: property?['default_nightly_rate']?.toString() ?? '');
    final cleaningCtrl = TextEditingController(text: property?['cleaning_fee']?.toString() ?? '');
    final imageUrlCtrl = TextEditingController(text: property?['image_url']?.toString() ?? '');
    final airbnbIcalCtrl = TextEditingController(text: property?['airbnb_ical_url']?.toString() ?? '');
    final bookingIcalCtrl = TextEditingController(text: property?['booking_com_ical_url']?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSubmitting = false;
        bool isUploadingImage = false;
        String? errorText;
        String previewUrl = imageUrlCtrl.text.trim();

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GinataColors.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.home_work_outlined, color: GinataColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Edit Property & Settings' : 'Add New Property',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: GinataColors.primary),
                  ),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Direct and manual host inventory. Supports direct bookings with no VAT and automatic iCal channel synchronization.',
                        style: TextStyle(fontSize: 12, color: GinataColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      if (errorText != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: GinataColors.errorContainer, borderRadius: BorderRadius.circular(8)),
                          child: Text(errorText!, style: const TextStyle(color: GinataColors.alertTerracotta, fontSize: 12)),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Cover Image Live Preview Section
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: previewUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  previewUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
                                        SizedBox(height: 4),
                                        Text('Image URL not reachable. Paste a valid link.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 36),
                                    SizedBox(height: 4),
                                    Text('Enter Cover Image URL below to preview', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 10),

                      // Image URL input & Choose File button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: imageUrlCtrl,
                              onChanged: (val) {
                                setDialogState(() => previewUrl = val.trim());
                              },
                              decoration: const InputDecoration(
                                labelText: 'Cover Image URL *',
                                hintText: 'Paste link or click Choose File',
                                prefixIcon: Icon(Icons.link, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GinataColors.primaryContainer,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: isUploadingImage
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.upload_file, size: 16),
                            label: Text(isUploadingImage ? 'Uploading...' : 'Choose File', style: const TextStyle(fontSize: 12)),
                            onPressed: isUploadingImage
                                ? null
                                : () async {
                                    try {
                                      final picked = await FilePicker.pickFile(
                                        type: FileType.image,
                                      );
                                      if (picked != null) {
                                        setDialogState(() => isUploadingImage = true);
                                        final bytes = await picked.readAsBytes();
                                        final uploadedUrl = await ApiService.uploadImage(bytes, picked.name);
                                        imageUrlCtrl.text = uploadedUrl;
                                        setDialogState(() {
                                          previewUrl = uploadedUrl;
                                          isUploadingImage = false;
                                        });
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        isUploadingImage = false;
                                        errorText = 'Upload failed: $e';
                                      });
                                    }
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Property Name *',
                          hintText: 'e.g. Karen Forest Pavilion',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cityCtrl,
                              decoration: const InputDecoration(labelText: 'City / Location *', hintText: 'Nairobi'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: countryCtrl,
                              decoration: const InputDecoration(labelText: 'Country *', hintText: 'Kenya'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Physical Address / Street',
                          hintText: 'e.g. Mbagathi Ridge, Gate 4',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: rateCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Nightly Rate (KES) *',
                                hintText: '15000',
                                prefixText: 'KES ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: cleaningCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cleaning Fee (KES)',
                                hintText: '3500',
                                prefixText: 'KES ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Direct rate & zero VAT indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: GinataColors.secondaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_outlined, size: 18, color: GinataColors.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Direct Pricing: 0.00% VAT (Standard VAT removed across all invoices & receipts)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GinataColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Optional Channel iCals
                      const Text('External Calendar Sync (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.textPrimary)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: airbnbIcalCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Airbnb iCal Feed URL',
                          hintText: 'https://www.airbnb.com/calendar/ical/...',
                          prefixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: bookingIcalCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Booking.com iCal Feed URL',
                          hintText: 'https://admin.booking.com/hotel/hoteladmin/ical.html?...',
                          prefixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GinataColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            setDialogState(() => errorText = 'Please provide a property name.');
                            return;
                          }
                          final nightlyRate = double.tryParse(rateCtrl.text.trim());
                          if (nightlyRate == null || nightlyRate <= 0) {
                            setDialogState(() => errorText = 'Please provide a valid nightly rate.');
                            return;
                          }

                          final cleaningFee = double.tryParse(cleaningCtrl.text.trim()) ?? 0.0;

                          setDialogState(() {
                            isSubmitting = true;
                            errorText = null;
                          });

                          try {
                            final payload = {
                              'name': nameCtrl.text.trim(),
                              'slug': nameCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
                              'address': addressCtrl.text.trim(),
                              'city': cityCtrl.text.trim(),
                              'country': countryCtrl.text.trim(),
                              'default_nightly_rate': nightlyRate,
                              'currency': 'KES',
                              'cleaning_fee': cleaningFee,
                              'tax_rate': 0.0, // VAT removed
                              'image_url': imageUrlCtrl.text.trim().isNotEmpty ? imageUrlCtrl.text.trim() : null,
                              'airbnb_ical_url': airbnbIcalCtrl.text.trim().isEmpty ? null : airbnbIcalCtrl.text.trim(),
                              'booking_com_ical_url': bookingIcalCtrl.text.trim().isEmpty ? null : bookingIcalCtrl.text.trim(),
                            };

                            if (isEditing) {
                              await ApiService.updateProperty(property['id'].toString(), payload);
                            } else {
                              await ApiService.createProperty(payload);
                            }
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx, true);
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: Text(isSubmitting ? 'Saving...' : (isEditing ? 'Save Changes' : 'Create Property')),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      _loadProperties();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Property updated successfully!' : 'Property created and ready for bookings!'),
            backgroundColor: GinataColors.primary,
          ),
        );
      }
    }
  }

  void _openInventoryModal(dynamic property) {
    showDialog(
      context: context,
      builder: (ctx) => _PropertyInventoryDialog(property: property),
    );
  }

  void _openCalendarSyncModal(dynamic property) {
    showDialog(
      context: context,
      builder: (ctx) => _PropertySyncDialog(
        property: property,
        onUpdated: () => _loadProperties(),
      ),
    );
  }

  void _confirmDelete(dynamic property) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Property?'),
        content: Text('Are you sure you want to delete "${property['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GinataColors.alertTerracotta),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteProperty(property['id'].toString());
        _loadProperties();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Property removed.'), backgroundColor: GinataColors.primary),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete: $e'), backgroundColor: GinataColors.alertTerracotta),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GinataColors.background,
      appBar: AppBar(
        title: const Text('Property Portfolio & Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: GinataColors.primary),
            tooltip: 'Reload',
            onPressed: _loadProperties,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GinataColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Property', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              onPressed: () => _openPropertyDialog(),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search properties...',
                            prefixIcon: const Icon(Icons.search, size: 20, color: GinataColors.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            fillColor: Colors.white,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: GinataColors.outlineVariant.withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.domain, size: 16, color: GinataColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              '${_properties.length}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GinataColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Properties List / Cards
                Expanded(
                  child: _filteredProperties.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.home_work_outlined, size: 54, color: GinataColors.secondary.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              const Text('No properties found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                              const SizedBox(height: 4),
                              const Text('Add direct properties to manage bookings, rates, inventory, and iCal feeds.', style: TextStyle(fontSize: 12, color: GinataColors.textSecondary)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GinataColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Your First Property'),
                                onPressed: () => _openPropertyDialog(),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                          itemCount: _filteredProperties.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 16),
                          itemBuilder: (ctx, idx) {
                            final prop = _filteredProperties[idx];
                            final nightlyRateKes = GinataFormatters.formatKES(prop['default_nightly_rate']);
                            final cleaningFeeKes = GinataFormatters.formatKES(prop['cleaning_fee']);
                            final imageUrl = prop['image_url']?.toString();
                            final hasAirbnbSync = (prop['airbnb_ical_url']?.toString().isNotEmpty ?? false);
                            final hasBookingSync = (prop['booking_com_ical_url']?.toString().isNotEmpty ?? false);

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0x18174A3F)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Banner with Cover Image
                                  Container(
                                    height: 150,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      color: GinataColors.surfaceContainerHigh,
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (imageUrl != null && imageUrl.isNotEmpty)
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                            child: Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: GinataColors.secondaryContainer.withValues(alpha: 0.3),
                                                child: const Icon(Icons.apartment, size: 48, color: GinataColors.secondary),
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            color: GinataColors.secondaryContainer.withValues(alpha: 0.3),
                                            child: const Icon(Icons.apartment, size: 48, color: GinataColors.secondary),
                                          ),
                                        // Gradient overlay
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withValues(alpha: 0.7),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Property Name & Location
                                        Positioned(
                                          left: 16,
                                          bottom: 12,
                                          right: 16,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      prop['name'] ?? 'Untitled Property',
                                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                                    ),
                                                    Text(
                                                      '${prop['city'] ?? ''}, ${prop['country'] ?? 'Kenya'} · ${prop['address'] ?? ''}',
                                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: GinataColors.primary,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.white30),
                                                ),
                                                child: Text(
                                                  '$nightlyRateKes / nt',
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Sync Badges on top-right
                                        Positioned(
                                          top: 10,
                                          right: 12,
                                          child: Row(
                                            children: [
                                              if (hasAirbnbSync)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 6),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFF5A5F),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Row(
                                                    children: [
                                                      Icon(Icons.sync, size: 10, color: Colors.white),
                                                      SizedBox(width: 4),
                                                      Text('Airbnb', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                                    ],
                                                  ),
                                                ),
                                              if (hasBookingSync)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 6),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF003580),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Row(
                                                    children: [
                                                      Icon(Icons.sync, size: 10, color: Colors.white),
                                                      SizedBox(width: 4),
                                                      Text('Booking.com', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Details Badges
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildMetricBadge(Icons.cleaning_services_outlined, 'Cleaning', cleaningFeeKes),
                                            const SizedBox(width: 8),
                                            _buildMetricBadge(Icons.shield_outlined, 'VAT', '0.0% Direct'),
                                            const SizedBox(width: 8),
                                            _buildMetricBadge(Icons.inventory_2_outlined, 'Inventory', 'Tracked'),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        // Actions Row
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: GinataColors.primary,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.add_circle_outline, size: 15),
                                              label: const Text('Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              onPressed: () async {
                                                final created = await showDialog<bool>(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (_) => ManualBookingDialog(
                                                    initialData: {'property_id': prop['id'].toString()},
                                                  ),
                                                );
                                                if (created == true && context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Reservation created successfully!'), backgroundColor: GinataColors.primary),
                                                  );
                                                }
                                              },
                                            ),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.inventory_2_outlined, size: 15, color: GinataColors.primary),
                                              label: const Text('Inventory', style: TextStyle(fontSize: 12, color: GinataColors.primary, fontWeight: FontWeight.w600)),
                                              onPressed: () => _openInventoryModal(prop),
                                            ),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.sync_alt, size: 15, color: Colors.blueGrey),
                                              label: const Text('Sync iCal', style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                                              onPressed: () => _openCalendarSyncModal(prop),
                                            ),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              icon: const Icon(Icons.edit_outlined, size: 15),
                                              label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _openPropertyDialog(property: prop),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: GinataColors.alertTerracotta, size: 20),
                                              tooltip: 'Delete Property',
                                              onPressed: () => _confirmDelete(prop),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMetricBadge(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: GinataColors.surfaceSubdued,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: GinataColors.secondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 9, color: GinataColors.textSecondary, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GinataColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PROPERTY INVENTORY MANAGEMENT DIALOG
// ==========================================
class _PropertyInventoryDialog extends StatefulWidget {
  final dynamic property;

  const _PropertyInventoryDialog({required this.property});

  @override
  State<_PropertyInventoryDialog> createState() => _PropertyInventoryDialogState();
}

class _PropertyInventoryDialogState extends State<_PropertyInventoryDialog> {
  bool _loading = true;
  List<dynamic> _items = [];
  bool _showAddForm = false;

  final _nameCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = 'Furniture';
  String _condition = 'Excellent';
  bool _isSaving = false;

  final List<String> _categories = ['Furniture', 'Linen', 'Electronics', 'Kitchenware', 'Bath & Amenities', 'Decor', 'Other'];
  final List<String> _conditions = ['Excellent', 'Good', 'Fair', 'Damaged', 'Needs Replacement'];

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() => _loading = true);
    try {
      final items = await ApiService.fetchPropertyInventory(widget.property['id'].toString());
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveItem() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final propId = widget.property['id'].toString();
      await ApiService.createInventoryItem(propId, {
        'property_id': propId,
        'name': _nameCtrl.text.trim(),
        'category': _category,
        'quantity': int.tryParse(_qtyCtrl.text.trim()) ?? 1,
        'condition': _condition,
        'room_location': _roomCtrl.text.trim().isEmpty ? null : _roomCtrl.text.trim(),
        'replacement_cost_kes': double.tryParse(_costCtrl.text.trim()),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      });

      _nameCtrl.clear();
      _costCtrl.clear();
      _notesCtrl.clear();
      setState(() {
        _showAddForm = false;
        _isSaving = false;
      });
      _fetchInventory();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving item: $e')));
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await ApiService.deleteInventoryItem(widget.property['id'].toString(), itemId);
      _fetchInventory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting item: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 680, maxHeight: screenHeight * 0.9),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GinataColors.secondaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: GinataColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inventory: ${widget.property['name'] ?? "Estate"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                              const Text('Track items, condition, and replacement costs', style: TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_items.length} Tracked Items', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: GinataColors.textPrimary)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showAddForm ? Colors.grey : GinataColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(_showAddForm ? Icons.close : Icons.add, size: 16),
                    label: Text(_showAddForm ? 'Cancel' : 'Add Item', style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _showAddForm = !_showAddForm),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Scrollable Area containing Add Form and Items List
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showAddForm) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(labelText: 'Item Name *', hintText: 'e.g. Smart TV, Linen Set, Coffee Machine'),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _category,
                                      decoration: const InputDecoration(labelText: 'Category'),
                                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                      onChanged: (val) => setState(() => _category = val ?? _category),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: _qtyCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Qty', hintText: '1'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _roomCtrl,
                                decoration: const InputDecoration(labelText: 'Room Location', hintText: 'e.g. Master Suite, Kitchen, Lounge'),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _condition,
                                      decoration: const InputDecoration(labelText: 'Condition'),
                                      items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                      onChanged: (val) => setState(() => _condition = val ?? _condition),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _costCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Cost (KES)', prefixText: 'KES ', hintText: '0'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _notesCtrl,
                                decoration: const InputDecoration(labelText: 'Notes / Serial No.', hintText: 'Model SN or warranty details'),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GinataColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: _isSaving ? null : _saveItem,
                                  child: _isSaving
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Save Inventory Item', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _loading
                          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: GinataColors.primary)))
                          : _items.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                                        const SizedBox(height: 8),
                                        const Text('No inventory items logged yet.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        const Text('Click "Add Item" above to track linens, furniture, and appliances.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final item = _items[i];
                              final cond = item['condition'] ?? 'Good';
                              final cost = item['replacement_cost_kes'];

                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: GinataColors.secondaryContainer.withValues(alpha: 0.4),
                                  child: Text('${item['quantity'] ?? 1}x', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GinataColors.primary)),
                                ),
                                title: Text(item['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  '${item['category'] ?? ''} • ${item['room_location'] ?? 'House'} ${cost != null ? "• Rep: ${GinataFormatters.formatKES(cost)}" : ""}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _getConditionColor(cond).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        cond,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getConditionColor(cond)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                      onPressed: () => _deleteItem(item['id'].toString()),
                                      tooltip: 'Remove',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getConditionColor(String cond) {
    switch (cond.toLowerCase()) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.teal;
      case 'fair':
        return Colors.amber.shade800;
      case 'damaged':
      case 'needs replacement':
        return GinataColors.alertTerracotta;
      default:
        return Colors.blueGrey;
    }
  }
}

// ==========================================
// AIRBNB & BOOKING.COM ICAL SYNC MODAL
// ==========================================
class _PropertySyncDialog extends StatefulWidget {
  final dynamic property;
  final VoidCallback onUpdated;

  const _PropertySyncDialog({required this.property, required this.onUpdated});

  @override
  State<_PropertySyncDialog> createState() => _PropertySyncDialogState();
}

class _PropertySyncDialogState extends State<_PropertySyncDialog> {
  late TextEditingController _airbnbCtrl;
  late TextEditingController _bookingCtrl;
  bool _saving = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _airbnbCtrl = TextEditingController(text: widget.property['airbnb_ical_url']?.toString() ?? '');
    _bookingCtrl = TextEditingController(text: widget.property['booking_com_ical_url']?.toString() ?? '');
  }

  String get _exportFeedUrl {
    final id = widget.property['id'].toString();
    return '${ApiService.baseUrl}/properties/$id/feed.ics';
  }

  Future<void> _saveIcalUrls() async {
    setState(() => _saving = true);
    try {
      final propId = widget.property['id'].toString();
      await ApiService.updateProperty(propId, {
        'airbnb_ical_url': _airbnbCtrl.text.trim().isEmpty ? null : _airbnbCtrl.text.trim(),
        'booking_com_ical_url': _bookingCtrl.text.trim().isEmpty ? null : _bookingCtrl.text.trim(),
      });
      widget.onUpdated();
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('iCal feeds saved!'), backgroundColor: GinataColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final propId = widget.property['id'].toString();
      final res = await ApiService.syncPropertyChannels(propId);
      widget.onUpdated();
      if (mounted) {
        setState(() => _syncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Calendar sync completed!'), backgroundColor: GinataColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _syncing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GinataColors.secondaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.sync_alt, color: GinataColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Channel Calendar Sync (iCal)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                              Text(widget.property['name'] ?? 'Property', style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Export Feed (Ginata to OTA)
              const Text('1. Export Feed (Paste this into Airbnb & Booking.com)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: GinataColors.textPrimary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _exportFeedUrl,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: GinataColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16, color: GinataColors.primary),
                      tooltip: 'Copy Feed URL',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _exportFeedUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Feed URL copied to clipboard!'), duration: Duration(seconds: 2)),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Import Feeds (OTA to Ginata)
              const Text('2. Import Feeds (Paste links from Airbnb / Booking.com here)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: GinataColors.textPrimary)),
              const SizedBox(height: 10),
              TextField(
                controller: _airbnbCtrl,
                decoration: const InputDecoration(
                  labelText: 'Airbnb iCal Feed URL',
                  hintText: 'https://www.airbnb.com/calendar/ical/...',
                  prefixIcon: Icon(Icons.home_work_outlined, size: 16, color: Color(0xFFFF5A5F)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bookingCtrl,
                decoration: const InputDecoration(
                  labelText: 'Booking.com iCal Feed URL',
                  hintText: 'https://admin.booking.com/hotel/hoteladmin/ical.html?...',
                  prefixIcon: Icon(Icons.hotel, size: 16, color: Color(0xFF003580)),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: _syncing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync, size: 16),
                    label: const Text('Sync Channels Now', style: TextStyle(fontSize: 12)),
                    onPressed: _syncing ? null : _syncNow,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GinataColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saving ? null : _saveIcalUrls,
                    child: _saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Feeds'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
