import 'ui/ui.dart';
import 'package:flutter/material.dart';

Map<String, WidgetBuilder> buildRoutes = {
  "/": (context) => IndexPage(),
  "peer_page": (context) => PeerPage(
        params: ModalRoute.of(context).settings.arguments,
      ),
  "message_list_page": (context) => MessageListPage(
        params: ModalRoute.of(context).settings.arguments,
      ),
};
