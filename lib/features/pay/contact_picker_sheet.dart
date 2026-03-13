import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../core/theme/app_theme.dart';

/// Data returned when a contact is picked.
class PickedContact {
  final String displayName;
  final String phone;

  const PickedContact({required this.displayName, required this.phone});
}

/// Bottom-sheet contact picker — shows a searchable list of device contacts.
///
/// Returns a [PickedContact] when the user taps a contact, or `null`
/// if the sheet is dismissed without selection.
class ContactPickerSheet extends StatefulWidget {
  const ContactPickerSheet({super.key});

  /// Show the picker as a modal bottom sheet and return the selected contact.
  static Future<PickedContact?> show(BuildContext context) {
    return showModalBottomSheet<PickedContact>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ContactPickerSheet(),
    );
  }

  @override
  State<ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<ContactPickerSheet> {
  List<Contact>? _allContacts;
  List<Contact> _filtered = [];
  final _searchController = TextEditingController();
  bool _permissionDenied = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    // flutter_contacts is not available on web
    if (kIsWeb) {
      if (mounted) setState(() { _permissionDenied = true; _loading = false; });
      return;
    }

    final hasPermission =
        await FlutterContacts.requestPermission(readonly: true);

    if (!hasPermission) {
      if (mounted) setState(() { _permissionDenied = true; _loading = false; });
      return;
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
      sorted: true,
    );

    // Keep only contacts that have at least one phone number
    final withPhone =
        contacts.where((c) => c.phones.isNotEmpty).toList();

    if (mounted) {
      setState(() {
        _allContacts = withPhone;
        _filtered = withPhone;
        _loading = false;
      });
    }
  }

  void _onSearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (_allContacts == null) return;

    if (query.isEmpty) {
      setState(() => _filtered = _allContacts!);
      return;
    }

    setState(() {
      _filtered = _allContacts!.where((c) {
        final nameMatch = c.displayName.toLowerCase().contains(query);
        final phoneMatch = c.phones
            .any((p) => p.number.replaceAll(RegExp(r'\D'), '').contains(query));
        return nameMatch || phoneMatch;
      }).toList();
    });
  }

  /// Normalize phone to last 10 digits (Indian mobile numbers).
  String _normalize(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  void _onContactTap(Contact contact) {
    final phone = _normalize(contact.phones.first.number);
    Navigator.of(context).pop(
      PickedContact(displayName: contact.displayName, phone: phone),
    );
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.scaffoldDark : AppTheme.scaffoldLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle bar ──
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.contacts_rounded,
                    color: AppTheme.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Pick a Contact',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or number',
                prefixIcon:
                    const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Contact list ──
          Expanded(child: _buildBody(theme, isDark)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading contacts...'),
          ],
        ),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.contacts_rounded,
                  size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Contacts Permission Required',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'PayTrace needs access to your contacts so you can pick someone to pay.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  // Re-request permission
                  setState(() { _loading = true; _permissionDenied = false; });
                  await _loadContacts();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_rounded,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No contacts match your search'
                    : 'No contacts with phone numbers found',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _filtered.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 68,
        color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
      ),
      itemBuilder: (context, index) {
        final contact = _filtered[index];
        final phone = contact.phones.first.number;
        final initials = _initials(contact.displayName);

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: _avatarColor(contact.displayName),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          title: Text(
            contact.displayName,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            phone,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded,
              size: 20,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: () => _onContactTap(contact),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _avatarColor(String name) {
    const colors = [
      AppTheme.primary,
      AppTheme.success,
      AppTheme.warning,
      AppTheme.error,
      AppTheme.primaryDark,
      Color(0xFF26A69A),
      Color(0xFF42A5F5),
      Color(0xFFAB47BC),
    ];
    final hash = name.codeUnits.fold<int>(0, (prev, c) => prev + c);
    return colors[hash % colors.length];
  }
}
