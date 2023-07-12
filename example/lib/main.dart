import 'package:flt_im_plugin/flt_im_plugin.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';

import 'router.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    FltImPlugin().init(host: "mm.3dsqq.com", apiURL: "http://mm.3dsqq.com:8000");
  }

  @override
  Widget build(BuildContext context) {
    return OKToast(
      textPadding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: MaterialApp(
        initialRoute: "/",
      ),
    );
  }
}
