import 'package:flt_im_plugin/value_util.dart';

class NativeResponse {
  int code;
  String message;
  var data;
  NativeResponse.fromMap(Map json) {
    code = ValueUtil.toInt(json['code']);
    message = ValueUtil.toStr(json['messsage']);
    data = json['data'];
  }
}
