import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'index_viewmodel.dart';

class IndexPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => IndexViewModel(),
      child: Consumer<IndexViewModel>(builder: (context, model, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Demo'),
          ),
          body: Column(
            children: [
              Container(
                padding: EdgeInsets.only(left: 20, right: 20, top: 20),
                child: TextField(
                  controller: TextEditingController(text: model.tfSender),
                  decoration: InputDecoration(hintText: '发送用户id'),
                  keyboardType: TextInputType.number,
                  onChanged: (text) => model.tfSender = text,
                ),
              ),
              Container(
                margin: EdgeInsets.only(top: 20),
                child: FlatButton(
                  color: Colors.blue,
                  onPressed: () {
                    FocusScope.of(context).requestFocus(FocusNode());
                    model.login(success: () {
                      if (model.tfReceiver != null && model.tfReceiver.length > 0) {
                        Navigator.of(context).pushNamed('peer_page', arguments: {
                          'currentUID': model.tfSender,
                          'peerUID': model.tfReceiver,
                        });
                      } else {
                        Navigator.of(context).pushNamed('message_list_page', arguments: {'currentUID': model.tfSender});
                      }
                    });
                  },
                  child: Text(
                    '登录',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
            ],
          ),
        );
      }),
    );
  }
}
