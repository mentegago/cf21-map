import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Utility class for encoding/decoding lists of integers with maximum compression
class IntEncoding {
  /// Encode a list of integers to a compact string using binary + Base64 encoding
  /// 
  /// Uses delta encoding for maximum compression:
  /// - First integer stored as full value
  /// - Subsequent integers stored as deltas from previous
  /// - Variable-length encoding for efficient byte usage
  /// - Base64 URL-safe encoding (no padding)
  static String intsToStringCode(List<int> ints) {
    if (ints.isEmpty) return '';
    
    // Sort integers for delta encoding
    final sortedInts = List<int>.from(ints)..sort();
    
    // Encode using variable-length encoding
    final bytes = <int>[];
    
    // First integer (full value)
    _writeVarInt(bytes, sortedInts[0]);
    
    // Subsequent integers as deltas
    for (int i = 1; i < sortedInts.length; i++) {
      final delta = sortedInts[i] - sortedInts[i - 1];
      _writeVarInt(bytes, delta);
    }
    
    // Convert to Base64 URL-safe encoding (no padding)
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Decode a compact string back to a list of integers
  /// 
  /// Handles the reverse of intsToStringCode:
  /// - Decodes Base64 to bytes
  /// - Reconstructs integers from first value + deltas
  /// - Returns empty list on decode errors
  static List<int> stringCodeToInts(String code) {
    if (code.isEmpty) return [];
    
    try {
      // Pad Base64 if needed
      while (code.length % 4 != 0) {
        code += '=';
      }
      
      final bytes = base64Url.decode(code);
      final ints = <int>[];
      int offset = 0;
      
      // Read first integer
      final firstInt = _readVarInt(bytes, offset);
      ints.add(firstInt.value);
      offset = firstInt.offset;
      
      // Read deltas and reconstruct integers
      while (offset < bytes.length) {
        final delta = _readVarInt(bytes, offset);
        ints.add(ints.last + delta.value);
        offset = delta.offset;
      }
      
      return ints;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to decode integer list: $e');
      }
      return [];
    }
  }

  /// Write a variable-length integer to byte list
  /// 
  /// Uses VLQ (Variable Length Quantity) encoding:
  /// - Each byte uses 7 bits for data, 1 bit for continuation
  /// - Small integers use fewer bytes
  static void _writeVarInt(List<int> bytes, int value) {
    while (value >= 128) {
      bytes.add((value & 0x7F) | 0x80);
      value >>= 7;
    }
    bytes.add(value & 0x7F);
  }

  /// Read a variable-length integer from byte list
  /// 
  /// Returns both the decoded value and the new offset position
  static ({int value, int offset}) _readVarInt(List<int> bytes, int offset) {
    int value = 0;
    int shift = 0;
    
    while (offset < bytes.length) {
      final byte = bytes[offset++];
      value |= (byte & 0x7F) << shift;
      
      if ((byte & 0x80) == 0) {
        break;
      }
      shift += 7;
    }
    
    return (value: value, offset: offset);
  }
}
