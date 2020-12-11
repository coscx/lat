import 'package:flutter/cupertino.dart';

import 'value_util.dart';
import 'message.dart';

enum ConversionType {
  CONVERSATION_PEER, // 1
  CONVERSATION_GROUP, // 2
  CONVERSATION_SYSTEM, // 3
  CONVERSATION_CUSTOMER_SERVICE, // 4
}

extension ConversionTypeStringParse on String {
  ConversionType get conversionType {
    switch (this) {
      case "CONVERSATION_PEER":
        return ConversionType.CONVERSATION_PEER;
      case "CONVERSATION_GROUP":
        return ConversionType.CONVERSATION_GROUP;
      case "CONVERSATION_SYSTEM":
        return ConversionType.CONVERSATION_SYSTEM;
      case "CONVERSATION_CUSTOMER_SERVICE":
        return ConversionType.CONVERSATION_CUSTOMER_SERVICE;
      default:
        return ConversionType.CONVERSATION_PEER;
    }
  }
}

extension ConversionTypeIntParse on int {
  ConversionType get conversionType {
    switch (this) {
      case 1:
        return ConversionType.CONVERSATION_PEER;
      case 2:
        return ConversionType.CONVERSATION_GROUP;
      case 3:
        return ConversionType.CONVERSATION_SYSTEM;
      case 4:
        return ConversionType.CONVERSATION_CUSTOMER_SERVICE;
      default:
        return ConversionType.CONVERSATION_PEER;
    }
  }
}

class Conversion {
  String cid;
  String name;
  String avatarURL;
  int newMsgCount;
  String detail;
  int timestamp;
  ConversionType type;
  Message message;

  Conversion.fromMap(Map json) {
    var typeObj = json['type'];
    if (typeObj is num) {
      type = ValueUtil.toInt(typeObj).conversionType;
    } else {
      type = ValueUtil.toStr(typeObj).conversionType;
    }
    cid = ValueUtil.toStr(json['cid']);
    name = ValueUtil.toStr(json['name']);
    avatarURL = ValueUtil.toStr(json['avatarURL']);
    if (avatarURL == null || avatarURL.length == 0) {
      avatarURL = ValueUtil.toStr(json['avatar']);
    }

    detail = ValueUtil.toStr(json['detail']);
    newMsgCount = ValueUtil.toInt(json['newMsgCount']);
    if (newMsgCount == 0) {
      newMsgCount = ValueUtil.toInt(json['unreadCount']);
    }

    timestamp = ValueUtil.toInt(json['timestamp']);
    message = Message.fromMap(ValueUtil.toMap(json['message']));
  }
}
