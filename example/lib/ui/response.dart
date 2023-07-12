import 'package:flt_im_plugin/value_util.dart';

class NativeResponse {
  late int code;
  late String message;
  late var data;
  NativeResponse.fromMap(Map json) {
    code = ValueUtil.toInt(json['code']);
    message = ValueUtil.toStr(json['messsage']);
    data = json['data'];
  }
}
