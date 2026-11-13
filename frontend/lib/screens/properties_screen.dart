import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
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
      final address = (p['address'] ?? '').toString().toLowerCase();
      final description = (p['description'] ?? '').toString().toLowerCase();
      final amenities = (p['amenities'] is List ? p['amenities'] as List : const [])
          .join(' ')
          .toString()
          .toLowerCase();
      return [
        name,
        city,
        country,
        address,
        description,
        amenities,
      ].any((value) => value.contains(q));
    }).toList();
  }

  void _openPropertyDialog({Map<String, dynamic>? property}) async {
    final isEditing = property != null;
    final nameCtrl = TextEditingController(text: property?['name']?.toString() ?? '');
    final addressCtrl = TextEditingController(text: property?['address']?.toString() ?? '');
    final cityCtrl = TextEditingController(text: property?['city']?.toString() ?? 'Nairobi');
    final countryCtrl = TextEditingController(text: property?['country']?.toString() ?? 'Kenya');
    final descriptionCtrl = TextEditingController(text: property?['description']?.toString() ?? '');
    final amenitiesCtrl = TextEditingController(
      text: (property?['amenities'] as List<dynamic>?)?.join(', ') ?? '',
    );
    final bedroomsCtrl = TextEditingController(text: property?['bedrooms']?.toString() ?? '');
    final bathroomsCtrl = TextEditingController(text: property?['bathrooms']?.toString() ?? '');
    final maxGuestsCtrl = TextEditingController(text: property?['max_guests']?.toString() ?? '');
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
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: previewUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      previewUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle, size: 14, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text('Cover Photo Active', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, color: GinataColors.secondary, size: 36),
                                    SizedBox(height: 6),
                                    Text('No cover photo chosen yet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.textPrimary)),
                                    SizedBox(height: 2),
                                    Text('Click Choose File below to upload image', style: TextStyle(fontSize: 11, color: GinataColors.textSecondary)),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 10),

                      // Choose File button full width
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GinataColors.primaryContainer,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: isUploadingImage
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.upload_file, size: 18),
                          label: Text(
                            isUploadingImage ? 'Uploading Image...' : (previewUrl.isNotEmpty ? 'Change Cover Photo' : 'Choose Cover Photo (from device)'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
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
                                      // Persist the cover immediately when editing an existing property
                                      // so the photo is saved and shown without needing "Save Changes".
                                      if (isEditing) {
                                        await ApiService.updateProperty(
                                          property['id'].toString(),
                                          {'image_url': uploadedUrl},
                                        );
                                      }
                                      setDialogState(() {
                                        previewUrl = uploadedUrl;
                                        isUploadingImage = false;
                                      });
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(isEditing ? 'Cover photo saved & applied!' : 'Cover photo ready — it will be saved with the property.'),
                                            backgroundColor: GinataColors.successSage,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    setDialogState(() {
                                      isUploadingImage = false;
                                      errorText = 'Upload failed: $e';
                                    });
                                  }
                                },
                        ),
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
                      TextField(
                        controller: descriptionCtrl,
                        maxLines: 3,
                        maxLength: 10000,
                        decoration: const InputDecoration(
                          labelText: 'Property Description',
                          hintText: 'What makes this place special?',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: bedroomsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Bedrooms',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: bathroomsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Bathrooms',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: maxGuestsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max guests',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amenitiesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Amenities',
                          hintText: 'Wi-Fi, Parking, Pool',
                          helperText: 'Separate amenities with commas.',
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

                          final bedroomText = bedroomsCtrl.text.trim();
                          final bathroomText = bathroomsCtrl.text.trim();
                          final maxGuestsText = maxGuestsCtrl.text.trim();
                          final bedrooms = bedroomText.isEmpty ? null : int.tryParse(bedroomText);
                          final bathrooms = bathroomText.isEmpty ? null : int.tryParse(bathroomText);
                          final maxGuests = maxGuestsText.isEmpty ? null : int.tryParse(maxGuestsText);
                          if ((bedroomText.isNotEmpty && (bedrooms == null || bedrooms < 0)) ||
                              (bathroomText.isNotEmpty && (bathrooms == null || bathrooms < 0)) ||
                              (maxGuestsText.isNotEmpty && (maxGuests == null || maxGuests < 1))) {
                            setDialogState(() => errorText = 'Enter valid room counts and a maximum guest count of at least one.');
                            return;
                          }
                          final amenities = amenitiesCtrl.text
                              .split(',')
                              .map((amenity) => amenity.trim())
                              .where((amenity) => amenity.isNotEmpty)
                              .toSet()
                              .toList();
                          if (amenities.length > 50) {
                            setDialogState(() => errorText = 'Enter no more than 50 amenities.');
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
                              'description': descriptionCtrl.text.trim().isEmpty ? null : descriptionCtrl.text.trim(),
                              'amenities': amenities,
                              'bedrooms': bedrooms,
                              'bathrooms': bathrooms,
                              'max_guests': maxGuests,
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

    for (final controller in [
      nameCtrl,
      addressCtrl,
      cityCtrl,
      countryCtrl,
      descriptionCtrl,
      amenitiesCtrl,
      bedroomsCtrl,
      bathroomsCtrl,
      maxGuestsCtrl,
      rateCtrl,
      cleaningCtrl,
      imageUrlCtrl,
      airbnbIcalCtrl,
      bookingIcalCtrl,
    ]) {
      controller.dispose();
    }

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

  // ==========================================
  // HOST TOOLS — 6 extra actions per property
  // ==========================================

  Future<void> _duplicateProperty(dynamic property) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Duplicate Property?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text('Create a copy of "${property['name']}" with the same rates, fees, cover photo and calendar feeds. Bookings and inventory are not copied.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GinataColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final baseName = '${property['name'] ?? 'Property'} (Copy)';
      final payload = {
        'name': baseName,
        'slug': '${baseName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch}',
        'address': property['address']?.toString() ?? '',
        'city': property['city']?.toString() ?? 'Nairobi',
        'country': property['country']?.toString() ?? 'Kenya',
        'default_nightly_rate': double.tryParse(property['default_nightly_rate']?.toString() ?? '0') ?? 0,
        'currency': property['currency']?.toString() ?? 'KES',
        'cleaning_fee': double.tryParse(property['cleaning_fee']?.toString() ?? '0') ?? 0,
        'tax_rate': 0.0,
        'image_url': property['image_url']?.toString(),
        'description': property['description'],
        'amenities': property['amenities'] ?? [],
        'bedrooms': property['bedrooms'],
        'bathrooms': property['bathrooms'],
        'max_guests': property['max_guests'],
        'airbnb_ical_url': property['airbnb_ical_url']?.toString(),
        'booking_com_ical_url': property['booking_com_ical_url']?.toString(),
      };
      await ApiService.createProperty(payload);
      await _loadProperties();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$baseName" created and ready to edit.'), backgroundColor: GinataColors.successSage),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not duplicate: $e'), backgroundColor: GinataColors.alertTerracotta),
        );
      }
    }
  }

  void _openAvailabilityDialog(dynamic property) {
    showDialog(context: context, builder: (_) => _PropertyAvailabilityDialog(property: property));
  }

  void _openPerformanceDialog(dynamic property) {
    showDialog(context: context, builder: (_) => _PropertyPerformanceDialog(property: property));
  }

  void _openPropertyExpensesDialog(dynamic property) {
    showDialog(context: context, builder: (_) => _PropertyExpensesDialog(property: property));
  }

  void _shareListing(dynamic property) {
    final feedUrl = '${ApiService.baseUrl}/properties/${property['id']}/feed.ics';
    final rate = GinataFormatters.formatKES(property['default_nightly_rate']);
    final cleaning = GinataFormatters.formatKES(property['cleaning_fee']);
    final location = [property['address'], property['city'], property['country']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .map((e) => e.toString())
        .join(', ');
    final blurb = StringBuffer()
      ..writeln('🏡 ${property['name'] ?? 'Property'}')
      ..writeln(location.isEmpty ? 'Kenya' : location)
      ..writeln('')
      ..writeln('Nightly rate: $rate (0% VAT — direct booking)')
      ..writeln('Cleaning fee: $cleaning')
      ..writeln('')
      ..writeln('Book direct with the host for the best rate.')
      ..writeln('Live availability calendar: $feedUrl');
    Clipboard.setData(ClipboardData(text: blurb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Listing details & availability link copied — paste into WhatsApp, Airbnb or email.'),
        backgroundColor: GinataColors.primary,
      ),
    );
  }

  Future<void> _exportPropertyReport(dynamic property) async {
    final propId = property['id'].toString();
    try {
      final summary = await ApiService.fetchFinancialSummary(propertyId: propId);
      final inventory = await ApiService.fetchPropertyInventory(propId);
      final reservations = await ApiService.fetchReservations(propertyId: propId);
      final active = reservations.where((r) => r['reservation_status'] != 'cancelled').length;
      final fmt = DateFormat('dd MMM yyyy, HH:mm');
      final report = StringBuffer()
        ..writeln('═══════════════════════════════════')
        ..writeln('  GINATA PROPERTY REPORT')
        ..writeln('  ${property['name'] ?? 'Property'}')
        ..writeln('  Generated ${fmt.format(DateTime.now())}')
        ..writeln('═══════════════════════════════════')
        ..writeln('')
        ..writeln('LOCATION')
        ..writeln('  ${property['address'] ?? ''}, ${property['city'] ?? ''}, ${property['country'] ?? 'Kenya'}')
        ..writeln('  ${property['description'] ?? ''}')
        ..writeln('  Bedrooms: ${property['bedrooms'] ?? 'Not set'}')
        ..writeln('  Bathrooms: ${property['bathrooms'] ?? 'Not set'}')
        ..writeln('  Maximum guests: ${property['max_guests'] ?? 'Not set'}')
        ..writeln('  Amenities: ${(property['amenities'] as List<dynamic>?)?.join(', ') ?? 'Not set'}')
        ..writeln('')
        ..writeln('RATES')
        ..writeln('  Nightly: ${GinataFormatters.formatKES(property['default_nightly_rate'])}')
        ..writeln('  Cleaning: ${GinataFormatters.formatKES(property['cleaning_fee'])}')
        ..writeln('  VAT: 0.00% (Direct)')
        ..writeln('')
        ..writeln('CHANNEL SYNC')
        ..writeln('  Airbnb: ${(property['airbnb_ical_url']?.toString().isNotEmpty ?? false) ? "Connected" : "Not set"}')
        ..writeln('  Booking.com: ${(property['booking_com_ical_url']?.toString().isNotEmpty ?? false) ? "Connected" : "Not set"}')
        ..writeln('')
        ..writeln('PERFORMANCE')
        ..writeln('  Active reservations: $active')
        ..writeln('  Inventory items tracked: ${inventory.length}')
        ..writeln('  Gross revenue: ${GinataFormatters.formatKES(summary['gross_revenue'])}')
        ..writeln('  Collected: ${GinataFormatters.formatKES(summary['collected_revenue'])}')
        ..writeln('  Pending balance: ${GinataFormatters.formatKES(summary['pending_balance'])}')
        ..writeln('  Expenses: ${GinataFormatters.formatKES(summary['total_expenses'])}')
        ..writeln('  Net operating profit: ${GinataFormatters.formatKES(summary['net_operating_profit'])}')
        ..writeln('')
        ..writeln('Availability feed: ${ApiService.baseUrl}/properties/$propId/feed.ics');
      await Clipboard.setData(ClipboardData(text: report.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full property report copied to clipboard.'), backgroundColor: GinataColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not build report: $e'), backgroundColor: GinataColors.alertTerracotta),
        );
      }
    }
  }

  Widget _hostToolChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GinataColors.background,
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Properties & Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
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
              label: Text(MediaQuery.sizeOf(context).width < 480 ? 'Add' : 'Add Property', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                            final description = prop['description']?.toString().trim() ?? '';
                            final amenities = (prop['amenities'] is List
                                    ? prop['amenities'] as List
                                    : const [])
                                .whereType<String>()
                                .where((amenity) => amenity.trim().isNotEmpty)
                                .toList();
                            final bedrooms = prop['bedrooms'];
                            final bathrooms = prop['bathrooms'];
                            final maxGuests = prop['max_guests'];
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
                                        if (description.isNotEmpty) ...[
                                          Text(
                                            description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.4,
                                              color: GinataColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        if (bedrooms != null ||
                                            bathrooms != null ||
                                            maxGuests != null) ...[
                                          Row(
                                            children: [
                                              if (bedrooms != null)
                                                _buildMetricBadge(
                                                  Icons.bedroom_parent_outlined,
                                                  'Bedrooms',
                                                  bedrooms.toString(),
                                                ),
                                              if (bedrooms != null &&
                                                  (bathrooms != null ||
                                                      maxGuests != null))
                                                const SizedBox(width: 8),
                                              if (bathrooms != null)
                                                _buildMetricBadge(
                                                  Icons.bathtub_outlined,
                                                  'Bathrooms',
                                                  bathrooms.toString(),
                                                ),
                                              if (bathrooms != null &&
                                                  maxGuests != null)
                                                const SizedBox(width: 8),
                                              if (maxGuests != null)
                                                _buildMetricBadge(
                                                  Icons.people_outline,
                                                  'Max guests',
                                                  maxGuests.toString(),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        if (amenities.isNotEmpty) ...[
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              for (final amenity
                                                  in amenities.take(6))
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 9,
                                                    vertical: 5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: GinataColors
                                                        .secondaryContainer
                                                        .withValues(alpha: 0.4),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    amenity,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: GinataColors
                                                          .primary,
                                                    ),
                                                  ),
                                                ),
                                              if (amenities.length > 6)
                                                Text(
                                                  '+${amenities.length - 6} more',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: GinataColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                        ],
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
                                        const SizedBox(height: 14),
                                        const Divider(height: 1),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Icon(Icons.auto_awesome, size: 13, color: GinataColors.brassGold),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'HOST TOOLS',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: GinataColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _hostToolChip(Icons.copy_all, 'Duplicate', GinataColors.primary, () => _duplicateProperty(prop)),
                                            _hostToolChip(Icons.event_available, 'Availability', const Color(0xFF1D4ED8), () => _openAvailabilityDialog(prop)),
                                            _hostToolChip(Icons.insights, 'Performance', GinataColors.successSage, () => _openPerformanceDialog(prop)),
                                            _hostToolChip(Icons.receipt_long, 'Expenses', GinataColors.warningOchre, () => _openPropertyExpensesDialog(prop)),
                                            _hostToolChip(Icons.ios_share, 'Share Listing', const Color(0xFFBE185D), () => _shareListing(prop)),
                                            _hostToolChip(Icons.summarize, 'Export Report', GinataColors.secondary, () => _exportPropertyReport(prop)),
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

// ==========================================
// HOST TOOL 1 — AVAILABILITY / UPCOMING STAYS
// ==========================================
class _PropertyAvailabilityDialog extends StatefulWidget {
  final dynamic property;
  const _PropertyAvailabilityDialog({required this.property});

  @override
  State<_PropertyAvailabilityDialog> createState() => _PropertyAvailabilityDialogState();
}

class _PropertyAvailabilityDialogState extends State<_PropertyAvailabilityDialog> {
  bool _loading = true;
  List<dynamic> _stays = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.fetchReservations(propertyId: widget.property['id'].toString());
      final stays = res.where((r) => r['reservation_status'] != 'cancelled').toList();
      stays.sort((a, b) {
        final da = DateTime.tryParse(a['check_in_date']?.toString() ?? '') ?? DateTime(2100);
        final db = DateTime.tryParse(b['check_in_date']?.toString() ?? '') ?? DateTime(2100);
        return da.compareTo(db);
      });
      if (mounted) setState(() { _stays = stays; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parse(dynamic v) => DateTime.tryParse(v?.toString() ?? '');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = _stays.where((s) {
      final out = _parse(s['check_out_date']);
      return out != null && !out.isBefore(today);
    }).toList();
    final nextIn = upcoming.isNotEmpty ? _parse(upcoming.first['check_in_date']) : null;
    final df = DateFormat('EEE, dd MMM yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: const Color(0xFF1D4ED8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.event_available, color: Color(0xFF1D4ED8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Availability & Stays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(widget.property['name']?.toString() ?? 'Property', style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${upcoming.length}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                          const Text('Upcoming / active stays', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                    if (nextIn != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('NEXT CHECK-IN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white70)),
                          const SizedBox(height: 3),
                          Text(df.format(nextIn), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
                    : _stays.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_busy, size: 44, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                const Text('No stays booked yet', style: TextStyle(fontWeight: FontWeight.bold, color: GinataColors.textPrimary)),
                                const SizedBox(height: 4),
                                const Text('This property is fully available. Create a booking to fill the calendar.', style: TextStyle(fontSize: 12, color: GinataColors.textSecondary), textAlign: TextAlign.center),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _stays.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final s = _stays[i];
                              final inD = _parse(s['check_in_date']);
                              final outD = _parse(s['check_out_date']);
                              final nights = (inD != null && outD != null) ? outD.difference(inD).inDays : 0;
                              final guest = s['primary_guest'];
                              final guestName = guest is Map ? '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'.trim() : 'Guest';
                              final status = (s['reservation_status'] ?? 'confirmed').toString();
                              final isPast = outD != null && outD.isBefore(today);
                              final statusColor = isPast
                                  ? GinataColors.textMuted
                                  : status == 'checked_in'
                                      ? GinataColors.successSage
                                      : const Color(0xFF1D4ED8);
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 44,
                                      decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(guestName.isEmpty ? 'Guest' : guestName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${inD != null ? df.format(inD) : '?'}  →  ${outD != null ? df.format(outD) : '?'}',
                                            style: const TextStyle(fontSize: 11, color: GinataColors.textSecondary),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                          child: Text(isPast ? 'completed' : status.replaceAll('_', ' '), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('$nights ${nights == 1 ? "night" : "nights"}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: GinataColors.textSecondary)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// HOST TOOL 2 — PERFORMANCE & REVENUE
// ==========================================
class _PropertyPerformanceDialog extends StatefulWidget {
  final dynamic property;
  const _PropertyPerformanceDialog({required this.property});

  @override
  State<_PropertyPerformanceDialog> createState() => _PropertyPerformanceDialogState();
}

class _PropertyPerformanceDialogState extends State<_PropertyPerformanceDialog> {
  bool _loading = true;
  Map<String, dynamic> _summary = {};
  int _bookings = 0;
  int _activeBookings = 0;
  int _totalNights = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final propId = widget.property['id'].toString();
    try {
      final results = await Future.wait([
        ApiService.fetchFinancialSummary(propertyId: propId),
        ApiService.fetchReservations(propertyId: propId),
      ]);
      final summary = results[0] as Map<String, dynamic>;
      final reservations = results[1] as List<dynamic>;
      int active = 0, nights = 0;
      for (final r in reservations) {
        if (r['reservation_status'] == 'cancelled') continue;
        active++;
        final inD = DateTime.tryParse(r['check_in_date']?.toString() ?? '');
        final outD = DateTime.tryParse(r['check_out_date']?.toString() ?? '');
        if (inD != null && outD != null) nights += outD.difference(inD).inDays;
      }
      if (mounted) {
        setState(() {
          _summary = summary;
          _bookings = reservations.length;
          _activeBookings = active;
          _totalNights = nights < 0 ? 0 : nights;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _num(String key) => double.tryParse(_summary[key]?.toString() ?? '0') ?? 0.0;

  Widget _metric(String label, String value, IconData icon, Color color, {String? sub}) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: GinataColors.textSecondary), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color))),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 9, color: GinataColors.textMuted)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gross = _num('gross_revenue');
    final collected = _num('collected_revenue');
    final pending = _num('pending_balance');
    final expenses = _num('total_expenses');
    final commissions = _num('total_agent_commissions');
    final net = _num('net_operating_profit');
    final collectionRate = gross > 0 ? (collected / gross).clamp(0.0, 1.0) : 0.0;
    final avgNightly = _totalNights > 0 ? gross / _totalNights : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600, maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: GinataColors.successSage.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.insights, color: GinataColors.successSage, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Performance & Revenue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(widget.property['name']?.toString() ?? 'Property', style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load, tooltip: 'Refresh'),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: GinataColors.primary))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [GinataColors.primary, GinataColors.primaryContainer]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('NET OPERATING PROFIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Colors.white70)),
                                  const SizedBox(height: 6),
                                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(GinataFormatters.formatKES(net), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white))),
                                  const SizedBox(height: 4),
                                  Text('Gross ${GinataFormatters.formatKES(gross)} − expenses ${GinataFormatters.formatKES(expenses)} − commissions ${GinataFormatters.formatKES(commissions)}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.7,
                              children: [
                                _metric('Gross Revenue', GinataFormatters.formatKES(gross), Icons.trending_up, GinataColors.primary),
                                _metric('Collected', GinataFormatters.formatKES(collected), Icons.payments_outlined, GinataColors.successSage),
                                _metric('Pending Balance', GinataFormatters.formatKES(pending), Icons.hourglass_bottom, GinataColors.warningOchre),
                                _metric('Total Expenses', GinataFormatters.formatKES(expenses), Icons.receipt_long, GinataColors.alertTerracotta),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: GinataColors.surfaceSubdued, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Collection progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GinataColors.textPrimary)),
                                      Text('${(collectionRate * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: GinataColors.successSage)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(value: collectionRate, minHeight: 9, backgroundColor: GinataColors.outlineVariant.withValues(alpha: 0.4), color: GinataColors.successSage),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('${GinataFormatters.formatKES(collected)} collected of ${GinataFormatters.formatKES(gross)} booked', style: const TextStyle(fontSize: 10, color: GinataColors.textSecondary)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('BOOKING ACTIVITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: GinataColors.textSecondary)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: _metric('Total Bookings', '$_bookings', Icons.book_online, const Color(0xFF1D4ED8))),
                                const SizedBox(width: 10),
                                Expanded(child: _metric('Active', '$_activeBookings', Icons.event_available, GinataColors.successSage)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: _metric('Nights Booked', '$_totalNights', Icons.nightlight_round, GinataColors.secondary)),
                                const SizedBox(width: 10),
                                Expanded(child: _metric('Avg / Night', GinataFormatters.formatKES(avgNightly), Icons.bedroom_parent, GinataColors.brassGold, sub: 'realized rate')),
                              ],
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
}

// ==========================================
// HOST TOOL 3 — PROPERTY EXPENSE LOG
// ==========================================
class _PropertyExpensesDialog extends StatefulWidget {
  final dynamic property;
  const _PropertyExpensesDialog({required this.property});

  @override
  State<_PropertyExpensesDialog> createState() => _PropertyExpensesDialogState();
}

class _PropertyExpensesDialogState extends State<_PropertyExpensesDialog> {
  bool _loading = true;
  bool _showForm = false;
  bool _saving = false;
  List<dynamic> _expenses = [];

  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  String _category = 'maintenance';
  String _method = 'mpesa';

  static const _categories = {
    'maintenance': 'Maintenance',
    'cleaning': 'Cleaning',
    'utilities': 'Utilities',
    'supplies': 'Supplies',
    'repairs': 'Repairs',
    'marketing': 'Marketing',
    'other': 'Other',
  };
  static const _methods = {'mpesa': 'M-Pesa', 'cash': 'Cash', 'bank': 'Bank Transfer', 'card': 'Card'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _vendorCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final exp = await ApiService.fetchExpenses(propertyId: widget.property['id'].toString());
      if (mounted) setState(() { _expenses = exp; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a title and a valid amount.'), backgroundColor: GinataColors.alertTerracotta));
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.createExpense({
        'property_id': widget.property['id'].toString(),
        'title': title,
        'category': _category,
        'amount': amount,
        'currency': 'KES',
        'expense_date': DateTime.now().toIso8601String().substring(0, 10),
        'vendor_name': _vendorCtrl.text.trim().isEmpty ? null : _vendorCtrl.text.trim(),
        'payment_method': _method,
      });
      _titleCtrl.clear();
      _amountCtrl.clear();
      _vendorCtrl.clear();
      if (mounted) setState(() { _showForm = false; _saving = false; });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense recorded.'), backgroundColor: GinataColors.successSage));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: GinataColors.alertTerracotta));
      }
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ApiService.deleteExpense(id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _expenses.fold<double>(0.0, (sum, e) => sum + (double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0));
    final df = DateFormat('dd MMM yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580, maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: GinataColors.warningOchre.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.receipt_long, color: GinataColors.warningOchre, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Property Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(widget.property['name']?.toString() ?? 'Property', style: const TextStyle(fontSize: 12, color: GinataColors.textSecondary), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: GinataColors.warningOchre.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TOTAL SPENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: GinataColors.warningOchre)),
                          const SizedBox(height: 3),
                          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(GinataFormatters.formatKES(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GinataColors.warningOchre))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showForm ? Colors.grey : GinataColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(_showForm ? Icons.close : Icons.add, size: 16),
                    label: Text(_showForm ? 'Cancel' : 'Add', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => setState(() => _showForm = !_showForm),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showForm) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: GinataColors.surfaceSubdued, borderRadius: BorderRadius.circular(12), border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.5))),
                          child: Column(
                            children: [
                              TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Expense title *', hintText: 'e.g. Plumbing repair, cleaning crew')),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: TextField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (KES) *', prefixText: 'KES '))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _category,
                                      isExpanded: true,
                                      decoration: const InputDecoration(labelText: 'Category'),
                                      items: _categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (v) => setState(() => _category = v ?? _category),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: TextField(controller: _vendorCtrl, decoration: const InputDecoration(labelText: 'Vendor / Payee', hintText: 'Optional'))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _method,
                                      isExpanded: true,
                                      decoration: const InputDecoration(labelText: 'Paid via'),
                                      items: _methods.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
                                      onChanged: (v) => setState(() => _method = v ?? _method),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: GinataColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
                                  onPressed: _saving ? null : _save,
                                  child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Record Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _loading
                          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: GinataColors.primary)))
                          : _expenses.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      children: [
                                        Icon(Icons.receipt_long_outlined, size: 42, color: Colors.grey.shade400),
                                        const SizedBox(height: 8),
                                        const Text('No expenses logged', style: TextStyle(fontWeight: FontWeight.bold, color: GinataColors.textPrimary)),
                                        const SizedBox(height: 4),
                                        const Text('Track maintenance, cleaning and utilities to see true net profit.', style: TextStyle(fontSize: 12, color: GinataColors.textSecondary), textAlign: TextAlign.center),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _expenses.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) {
                                    final e = _expenses[i];
                                    final cat = (e['category'] ?? 'other').toString();
                                    final catLabel = _categories[cat] ?? cat;
                                    final date = DateTime.tryParse(e['expense_date']?.toString() ?? '');
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: GinataColors.outlineVariant.withValues(alpha: 0.5))),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(e['title']?.toString() ?? 'Expense', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 3),
                                                Text('$catLabel • ${date != null ? df.format(date) : ''}${e['vendor_name'] != null && e['vendor_name'].toString().isNotEmpty ? " • ${e['vendor_name']}" : ""}', style: const TextStyle(fontSize: 10, color: GinataColors.textSecondary), overflow: TextOverflow.ellipsis),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(GinataFormatters.formatKES(e['amount']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: GinataColors.alertTerracotta)),
                                          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey), onPressed: () => _delete(e['id'].toString()), tooltip: 'Remove'),
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
}
