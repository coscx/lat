import 'package:flt_im_plugin/flt_im_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'message_list_viewmodel.dart';
import 'package:flt_im_plugin/conversion.dart';
import 'dialog.dart';

class MessageListPage extends StatelessWidget {
  final Map params;
  MessageListPage({required this.params});
  final TextEditingController _vc = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => MessageListViewModel(params),
      child: Consumer<MessageListViewModel>(builder: (ctx, model, child) {
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: Icon(Icons.arrow_right),
                onPressed: () {
                  FltImPlugin im = FltImPlugin();
                  im.videoCall("2");
                },
              ),
              IconButton(
                icon: Icon(Icons.arrow_left),
                onPressed: () {
                  FltImPlugin im = FltImPlugin();
                  im.VideoReceiveCall();
                },
              ),
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () {
                  FltImPlugin im = FltImPlugin();
                  im.voiceCall("2");
                },
              ),
              IconButton(
                icon: Icon(Icons.chevron_left),
                onPressed: () {
                  FltImPlugin im = FltImPlugin();
                  im.voiceReceiveCall();
                },
              ),
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () {
                  showDialog(
                    barrierDismissible: false,
                    context: ctx,
                    builder: (context) {
                      return RenameDialog(
                        contentWidget: RenameDialogContent(
                          title: "请输入对方的 id",
                          okBtnTap: () {
                            String text = _vc.text;
                            Future.delayed(Duration(milliseconds: 250), () {
                              model.addConversion(text, ctx);
                            });
                          },
                          vc: _vc,
                          cancelBtnTap: () {},
                        ),
                      );
                    },
                  );
                },
              )
            ],
            title: Text('List'),
          ),
          body: ListView.builder(
            itemBuilder: (context, index) {
              Conversion con = model.conversions[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  model.addConversion(con.cid!, context);
                },
                child: Container(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        margin: EdgeInsets.only(right: 10),
                        alignment: Alignment.center,
                        child: Text(
                          con.name!,
                          style: TextStyle(color: Colors.white),
                        ),
                        color: Colors.blue,
                      ),
                      Text(con.detail!)
                    ],
                  ),
                ),
              );
            },
            itemCount: model.conversions.length,
          ),
        );
      }),
    );
  }
}
