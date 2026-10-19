import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:scaneliq/features/ocr/data/ocr_service.dart';

class BusinessCardContact {
  final String name;
  final String company;
  final String jobTitle;
  final String phone;
  final String email;
  final String website;
  final String address;
  final String rawText;

  const BusinessCardContact({
    this.name = '',
    this.company = '',
    this.jobTitle = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.address = '',
    this.rawText = '',
  });

  BusinessCardContact copyWith({
    String? name,
    String? company,
    String? jobTitle,
    String? phone,
    String? email,
    String? website,
    String? address,
    String? rawText,
  }) {
    return BusinessCardContact(
      name: name ?? this.name,
      company: company ?? this.company,
      jobTitle: jobTitle ?? this.jobTitle,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      address: address ?? this.address,
      rawText: rawText ?? this.rawText,
    );
  }

  /// Generates a standardized vCard 3.0 string compatible with Android & iOS Contacts
  String toVCard() {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    if (name.isNotEmpty) {
      buffer.writeln('FN:$name');
      final parts = name.split(' ');
      if (parts.length > 1) {
        buffer.writeln(
          'N:${parts.last};${parts.sublist(0, parts.length - 1).join(' ')};;;',
        );
      } else {
        buffer.writeln('N:$name;;;;');
      }
    }
    if (company.isNotEmpty) buffer.writeln('ORG:$company');
    if (jobTitle.isNotEmpty) buffer.writeln('TITLE:$jobTitle');
    if (phone.isNotEmpty) buffer.writeln('TEL;TYPE=CELL,VOICE:$phone');
    if (email.isNotEmpty) buffer.writeln('EMAIL;TYPE=PREF,INTERNET:$email');
    if (website.isNotEmpty) buffer.writeln('URL:$website');
    if (address.isNotEmpty) {
      final sanitizedAdr = address.replaceAll('\n', ', ');
      buffer.writeln('ADR;TYPE=WORK:;;$sanitizedAdr;;;;');
    }
    buffer.writeln('NOTE:Scanned and extracted by Scaneliq');
    buffer.writeln('END:VCARD');
    return buffer.toString();
  }
}

/// Service providing Business Card contact extraction and vCard generation (F-33).
class BusinessCardService {
  BusinessCardService._();
  static final BusinessCardService instance = BusinessCardService._();

  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  static final RegExp _phoneRegex = RegExp(
    r'(?:\+?\d{1,3}[-.\s]?)?\(?\d{2,4}\)?[-.\s]?\d{3,4}[-.\s]?\d{3,4}',
  );

  static final RegExp _websiteRegex = RegExp(
    r'(?:https?:\/\/|www\.)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:\/[^\s]*)?',
    caseSensitive: false,
  );

  static final List<String> _titleKeywords = [
    'engineer',
    'developer',
    'designer',
    'manager',
    'director',
    'founder',
    'ceo',
    'cto',
    'cfo',
    'coo',
    'vp',
    'vice president',
    'president',
    'specialist',
    'consultant',
    'architect',
    'lead',
    'analyst',
    'officer',
    'executive',
    'partner',
    'associate',
    'administrator',
    'doctor',
    'professor',
    'advocate',
    'attorney',
    'head of',
  ];

  static final List<String> _companyKeywords = [
    'inc',
    'llc',
    'ltd',
    'corp',
    'corporation',
    'technologies',
    'solutions',
    'systems',
    'software',
    'studio',
    'labs',
    'group',
    'holdings',
    'bank',
    'hospital',
    'consulting',
    'enterprises',
    'agency',
    'company',
    'co.',
  ];

  /// Performs full workflow: runs OCR on image and extracts structured contact fields
  Future<BusinessCardContact> extractFromImage(File imageFile) async {
    final ocrText = await OcrService.instance.extractText(imageFile);
    return parseText(ocrText);
  }

  /// Parses raw text into structured BusinessCardContact
  BusinessCardContact parseText(String text) {
    if (text.trim().isEmpty) {
      return const BusinessCardContact();
    }

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String foundEmail = '';
    String foundPhone = '';
    String foundWebsite = '';
    String foundTitle = '';
    String foundCompany = '';
    String foundName = '';
    final List<String> addressLines = [];

    // 1. First pass: extract regex matches (Email, Phone, Website)
    for (final line in lines) {
      if (foundEmail.isEmpty) {
        final m = _emailRegex.firstMatch(line);
        if (m != null) foundEmail = m.group(0)!;
      }
      if (foundPhone.isEmpty) {
        final m = _phoneRegex.firstMatch(line);
        if (m != null) {
          final p = m.group(0)!;
          // Clean minimum length check (at least 7 digits)
          if (p.replaceAll(RegExp(r'\D'), '').length >= 7) {
            foundPhone = p;
          }
        }
      }
      if (foundWebsite.isEmpty) {
        final m = _websiteRegex.firstMatch(line);
        if (m != null) foundWebsite = m.group(0)!;
      }
    }

    // 2. Second pass: identify Company, Title, Name, Address
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      // Skip lines that are purely email, phone, or website
      if (line == foundEmail || line == foundPhone || line == foundWebsite) {
        continue;
      }
      if (_emailRegex.hasMatch(line) ||
          _phoneRegex.hasMatch(line) ||
          _websiteRegex.hasMatch(line)) {
        continue;
      }

      // Check for Job Title
      if (foundTitle.isEmpty) {
        for (final kw in _titleKeywords) {
          if (lower.contains(kw)) {
            foundTitle = line;
            break;
          }
        }
        if (foundTitle.isNotEmpty) continue;
      }

      // Check for Company
      if (foundCompany.isEmpty) {
        for (final kw in _companyKeywords) {
          final pattern = RegExp(
            r'\b' + RegExp.escape(kw) + r'\b',
            caseSensitive: false,
          );
          if (pattern.hasMatch(lower)) {
            foundCompany = line;
            break;
          }
        }
        if (foundCompany.isNotEmpty) continue;
      }

      // Check for Address
      if (lower.contains('street') ||
          lower.contains(' st.') ||
          lower.contains('ave') ||
          lower.contains('road') ||
          lower.contains('rd.') ||
          lower.contains('suite') ||
          lower.contains('floor') ||
          lower.contains('box') ||
          RegExp(r'\b\d{5}\b').hasMatch(line)) {
        addressLines.add(line);
        continue;
      }

      // Check for Candidate Name
      // Typically: 2-4 words, starts with capital letters, no special characters or digits
      if (foundName.isEmpty) {
        final words = line.split(RegExp(r'\s+'));
        final isAlphaOnly = RegExp(r'^[a-zA-Z\s\.\-]+$').hasMatch(line);
        if (words.length >= 2 && words.length <= 4 && isAlphaOnly) {
          final isTitleCase = words.every(
            (w) => w.isNotEmpty && w[0].toUpperCase() == w[0],
          );
          if (isTitleCase) {
            foundName = line;
            continue;
          }
        }
      }
    }

    // Fallback for name if not identified: pick first non-empty line that isn't title/company
    if (foundName.isEmpty && lines.isNotEmpty) {
      for (final line in lines) {
        if (line != foundEmail &&
            line != foundPhone &&
            line != foundWebsite &&
            line != foundTitle &&
            line != foundCompany &&
            !addressLines.contains(line) &&
            line.length >= 3 &&
            line.length <= 40) {
          foundName = line;
          break;
        }
      }
    }

    return BusinessCardContact(
      name: foundName,
      company: foundCompany,
      jobTitle: foundTitle,
      phone: foundPhone,
      email: foundEmail,
      website: foundWebsite,
      address: addressLines.join('\n'),
      rawText: text,
    );
  }

  /// Exports contact as a .vcf file into temporary or app documents directory
  Future<File> exportVCardFile(
    BusinessCardContact contact, {
    String? fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeName =
        (contact.name.isNotEmpty
                ? contact.name.replaceAll(RegExp(r'[^\w\s\-]'), '_')
                : 'Contact_${DateTime.now().millisecondsSinceEpoch}')
            .replaceAll(' ', '_');
    final file = File('${dir.path}/${fileName ?? safeName}.vcf');
    await file.writeAsString(contact.toVCard());
    return file;
  }
}
