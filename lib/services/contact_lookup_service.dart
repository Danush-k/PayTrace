import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// Contact Lookup Service — matches phone numbers from UPI IDs
/// against device contacts to resolve real names.
///
/// Flow:
///   1. Extract 10-digit phone number from UPI ID (e.g., "9876543210@ybl")
///   2. Look up in device contacts
///   3. Return the contact display name if found
///
/// Caches results in-memory for the sync session to avoid repeated lookups.
class ContactLookupService {
  ContactLookupService._();

  /// In-memory cache: phone number → contact name
  static final Map<String, String?> _cache = {};

  /// Whether we have contacts permission
  static bool? _hasPermission;

  /// Try to resolve a name from a UPI ID by looking up the phone number
  /// in device contacts.
  ///
  /// UPI IDs are often phone-number-based:
  ///   - 9876543210@ybl
  ///   - 9876543210@paytm
  ///   - 9876543210-1@okicici
  ///
  /// Returns the contact display name, or null if not found.
  static Future<String?> lookupFromUpiId(String? upiId) async {
    if (upiId == null || upiId.isEmpty) return null;

    // Extract phone number from UPI ID
    final phone = extractPhoneNumber(upiId);
    if (phone == null) return null;

    return lookupByPhone(phone);
  }

  /// Look up a contact name by phone number.
  static Future<String?> lookupByPhone(String phone) async {
    // Check cache first
    if (_cache.containsKey(phone)) return _cache[phone];

    // Check permission
    if (_hasPermission == null) {
      _hasPermission = await FlutterContacts.requestPermission(readonly: true);
    }
    if (_hasPermission != true) {
      debugPrint('PayTrace Contacts: No contacts permission');
      return null;
    }

    try {
      // Normalize the phone number for matching
      final normalized = _normalizePhone(phone);
      
      // Get all contacts with phone numbers
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      for (final contact in contacts) {
        for (final contactPhone in contact.phones) {
          final contactNormalized = _normalizePhone(contactPhone.number);
          if (contactNormalized == normalized ||
              contactNormalized.endsWith(normalized) ||
              normalized.endsWith(contactNormalized)) {
            final name = contact.displayName;
            if (name.isNotEmpty) {
              _cache[phone] = name;
              debugPrint('PayTrace Contacts: $phone → $name');
              return name;
            }
          }
        }
      }

      // Not found — cache the miss too
      _cache[phone] = null;
      debugPrint('PayTrace Contacts: $phone → not found');
      return null;
    } catch (e) {
      debugPrint('PayTrace Contacts: Error looking up $phone — $e');
      return null;
    }
  }

  /// Extract a 10-digit Indian phone number from a UPI ID.
  ///
  /// Examples:
  ///   "9876543210@ybl"      → "9876543210"
  ///   "9876543210-1@okicici" → "9876543210"
  ///   "919876543210@upi"     → "9876543210"
  ///   "merchant.name@ybl"   → null (not a phone number)
  static String? extractPhoneNumber(String upiId) {
    // Get the local part (before @)
    final atIndex = upiId.indexOf('@');
    if (atIndex <= 0) return null;

    final localPart = upiId.substring(0, atIndex);

    // Remove any suffix like "-1", "-2" (multi-account indicators)
    final cleaned = localPart.replaceAll(RegExp(r'-\d+$'), '');

    // Remove country code prefix
    String digits = cleaned.replaceAll(RegExp(r'[^0-9]'), '');

    // Handle +91 or 91 prefix
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }

    // Must be exactly 10 digits and start with 6-9 (Indian mobile)
    if (digits.length == 10 && RegExp(r'^[6-9]').hasMatch(digits)) {
      return digits;
    }

    return null;
  }

  /// Normalize a phone number for comparison.
  /// Strips all non-digits and removes country code.
  static String _normalizePhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove +91 or 91 prefix
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }

    return digits;
  }

  /// Clear the in-memory cache (call between sync sessions if needed).
  static void clearCache() {
    _cache.clear();
    _hasPermission = null;
  }
}
