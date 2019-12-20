import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:provider/provider.dart';
import 'package:cake_wallet/palette.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/widgets/address_text_field.dart';
import 'package:cake_wallet/src/widgets/primary_button.dart';
import 'package:cake_wallet/src/stores/settings/settings_store.dart';
import 'package:cake_wallet/src/stores/balance/balance_store.dart';
import 'package:cake_wallet/src/stores/wallet/wallet_store.dart';
import 'package:cake_wallet/src/stores/send/send_store.dart';
import 'package:cake_wallet/src/stores/send/sending_state.dart';
import 'package:cake_wallet/src/screens/base_page.dart';
import 'package:cake_wallet/src/domain/common/crypto_currency.dart';
import 'package:cake_wallet/src/domain/common/transaction_priority.dart';
import 'package:cake_wallet/src/domain/common/balance_display_mode.dart';
import 'package:cake_wallet/src/domain/common/calculate_estimated_fee.dart';
import 'package:cake_wallet/generated/i18n.dart';

class SendPage extends BasePage {
  String get title => S.current.send_title;
  bool get isModalBackButton => true;
  bool get resizeToAvoidBottomPadding => false;

  @override
  Widget body(BuildContext context) => SendForm();
}

class SendForm extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SendFormState();
}

class SendFormState extends State<SendForm> {
  final _addressController = TextEditingController();
  final _paymentIdController = TextEditingController();
  final _cryptoAmountController = TextEditingController();
  final _fiatAmountController = TextEditingController();

  bool _effectsInstalled = false;

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final settingsStore = Provider.of<SettingsStore>(context);
    final sendStore = Provider.of<SendStore>(context);
    sendStore.settingsStore = settingsStore;
    final balanceStore = Provider.of<BalanceStore>(context);
    final walletStore = Provider.of<WalletStore>(context);

    _setEffects(context);

    return Form(
        key: _formKey,
        child: Column(children: <Widget>[
          Container(
            padding: EdgeInsets.only(left: 38, right: 30),
            decoration: BoxDecoration(
                color: Theme.of(context).backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Palette.shadowGrey,
                    blurRadius: 10,
                    offset: Offset(
                      0,
                      12,
                    ),
                  )
                ],
                border: Border(
                    top: BorderSide(
                        width: 1,
                        color: Theme.of(context)
                            .accentTextTheme
                            .subtitle
                            .backgroundColor))),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Observer(builder: (_) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(S.of(context).send_your_wallet,
                              style: TextStyle(
                                  fontSize: 12, color: Palette.lightViolet)),
                          Text(walletStore.name,
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(context)
                                      .accentTextTheme
                                      .overline
                                      .color,
                                  height: 1.25)),
                        ]);
                  }),
                  Observer(builder: (context) {
                    final savedDisplayMode = settingsStore.balanceDisplayMode;
                    final availableBalance =
                        savedDisplayMode == BalanceDisplayMode.hiddenBalance
                            ? '---'
                            : balanceStore.unlockedBalance;

                    return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(S.of(context).xmr_available_balance,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .accentTextTheme
                                    .overline
                                    .backgroundColor,
                              )),
                          Text(availableBalance,
                              style: TextStyle(
                                  fontSize: 22,
                                  color: Theme.of(context)
                                      .accentTextTheme
                                      .overline
                                      .color,
                                  height: 1.1)),
                        ]);
                  })
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
                padding:
                    EdgeInsets.only(left: 38, right: 33, top: 10, bottom: 30),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(children: <Widget>[
                        AddressTextField(
                          controller: _addressController,
                          placeholder: S.of(context).send_monero_address,
                          onURIScanned: (uri) {
                            var address = '';
                            var amount = '';
                            var paymentId = '';

                            if (uri != null) {
                              address = uri.path;
                              amount = uri.queryParameters['tx_amount'];
                              paymentId = uri.queryParameters['tx_payment_id'];
                            } else {
                              address = uri.toString();
                            }

                            _addressController.text = address;
                            _cryptoAmountController.text = amount;
                            _paymentIdController.text = paymentId;
                          },
                          options: [
                            AddressTextFieldOption.qrCode,
                            AddressTextFieldOption.addressBook
                          ],
                          validator: (value) {
                            sendStore.validateAddress(value,
                                cryptoCurrency: CryptoCurrency.xmr);
                            return sendStore.errorMessage;
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: TextFormField(
                              style: TextStyle(
                                  fontSize: 14.0,
                                  color: Theme.of(context)
                                      .accentTextTheme
                                      .overline
                                      .backgroundColor),
                              controller: _paymentIdController,
                              decoration: InputDecoration(
                                  hintStyle: TextStyle(
                                      fontSize: 14.0,
                                      color: Theme.of(context).hintColor),
                                  hintText: S.of(context).send_payment_id,
                                  focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Theme.of(context).focusColor,
                                          width: 1.0)),
                                  enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Theme.of(context).focusColor,
                                          width: 1.0))),
                              validator: (value) {
                                sendStore.validatePaymentID(value);
                                return sendStore.errorMessage;
                              }),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: TextFormField(
                              showCursor: false,
                              style: TextStyle(
                                  fontSize: 18.0,
                                  color: Theme.of(context)
                                      .accentTextTheme
                                      .overline
                                      .color),
                              controller: _cryptoAmountController,
                              keyboardType: TextInputType.numberWithOptions(
                                  signed: false, decimal: false),
                              inputFormatters: [
                                BlacklistingTextInputFormatter(
                                    new RegExp('[\\-|\\ |\\,]'))
                              ],
                              decoration: InputDecoration(
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Text('XMR:',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Theme.of(context)
                                              .accentTextTheme
                                              .overline
                                              .color,
                                        )),
                                  ),
                                  suffixIcon: Container(
                                    width: 1,
                                    padding: EdgeInsets.only(top: 0),
                                    child: Center(
                                      child: InkWell(
                                          onTap: () => sendStore.setSendAll(),
                                          child: Text(S.of(context).all,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Theme.of(context)
                                                      .accentTextTheme
                                                      .overline
                                                      .decorationColor))),
                                    ),
                                  ),
                                  hintStyle: TextStyle(
                                      fontSize: 18.0,
                                      color: Theme.of(context).hintColor),
                                  hintText: '0.0000',
                                  focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Theme.of(context).focusColor,
                                          width: 1.0)),
                                  enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Theme.of(context).focusColor,
                                          width: 1.0))),
                              validator: (value) {
                                sendStore.validateXMR(
                                    value, balanceStore.unlockedBalance);
                                return sendStore.errorMessage;
                              }),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: TextFormField(
                              showCursor: false,
                              style: TextStyle(
                                  fontSize: 18.0,
                                  color: Theme.of(context)
                                      .accentTextTheme
                                      .overline
                                      .color),
                              controller: _fiatAmountController,
                              keyboardType: TextInputType.numberWithOptions(
                                  signed: false, decimal: false),
                              inputFormatters: [
                                BlacklistingTextInputFormatter(
                                    new RegExp('[\\-|\\ |\\,]'))
                              ],
                              decoration: InputDecoration(
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Text(
                                        '${settingsStore.fiatCurrency.toString()}:',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Theme.of(context)
                                              .accentTextTheme
                                              .overline
                                              .color,
                                        )),
                                  ),
                                  hintStyle: TextStyle(
                                      fontSize: 18.0,
                                      color: Theme.of(context).hintColor),
                                  hintText: '0.00',
                                  focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Theme.of(context).focusColor,
                                          width: 1.0)),
                                  enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Theme.of(context).focusColor,
                                          width: 1.0)))),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0, bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(S.of(context).send_estimated_fee,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .accentTextTheme
                                        .overline
                                        .backgroundColor,
                                  )),
                              Text(
                                  '${calculateEstimatedFee(priority: settingsStore.transactionPriority)} XMR',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .primaryTextTheme
                                        .overline
                                        .backgroundColor,
                                  ))
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                              S.of(context).send_priority(settingsStore
                                  .transactionPriority
                                  .toString()),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context)
                                      .primaryTextTheme
                                      .subtitle
                                      .color,
                                  height: 1.3)),
                        ),
                      ]),
                      Observer(builder: (_) {
                        return LoadingPrimaryButton(
                            onPressed: () async {
                              if (_formKey.currentState.validate()) {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: Text(S
                                            .of(context)
                                            .send_creating_transaction),
                                        content:
                                            Text(S.of(context).confirm_sending),
                                        actions: <Widget>[
                                          FlatButton(
                                              child: Text(S.of(context).send),
                                              onPressed: () async {
                                                Navigator.of(context)
                                                    .popAndPushNamed(
                                                        Routes.auth, arguments:
                                                            (isAuthenticatedSuccessfully,
                                                                auth) {
                                                  if (!isAuthenticatedSuccessfully) {
                                                    return;
                                                  }

                                                  Navigator.of(auth.context)
                                                      .pop();
                                                  sendStore.createTransaction(
                                                      address:
                                                          _addressController
                                                              .text,
                                                      paymentId:
                                                          _paymentIdController
                                                              .text);
                                                });
                                              }),
                                          FlatButton(
                                              child: Text(S.of(context).cancel),
                                              onPressed: () =>
                                                  Navigator.of(context).pop())
                                        ],
                                      );
                                    });
                              }
                            },
                            text: S.of(context).send,
                            color: Theme.of(context)
                                .accentTextTheme
                                .button
                                .backgroundColor,
                            borderColor: Theme.of(context)
                                .accentTextTheme
                                .button
                                .decorationColor,
                            isLoading: sendStore.state is CreatingTransaction ||
                                sendStore.state is TransactionCommitted);
                      })
                    ])),
          )
        ]));
  }

  void _setEffects(BuildContext context) {
    if (_effectsInstalled) {
      return;
    }

    final sendStore = Provider.of<SendStore>(context);

    reaction((_) => sendStore.fiatAmount, (amount) {
      if (amount != _fiatAmountController.text) {
        _fiatAmountController.text = amount;
      }
    });

    reaction((_) => sendStore.cryptoAmount, (amount) {
      if (amount != _cryptoAmountController.text) {
        _cryptoAmountController.text = amount;
      }
    });

    _fiatAmountController.addListener(() {
      final fiatAmount = _fiatAmountController.text;

      if (sendStore.fiatAmount != fiatAmount) {
        sendStore.changeFiatAmount(fiatAmount);
      }
    });

    _cryptoAmountController.addListener(() {
      final cryptoAmount = _cryptoAmountController.text;

      if (sendStore.cryptoAmount != cryptoAmount) {
        sendStore.changeCryptoAmount(cryptoAmount);
      }
    });

    reaction((_) => sendStore.state, (state) {
      if (state is SendingFailed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(S.of(context).error),
                  content: Text(state.error),
                  actions: <Widget>[
                    FlatButton(
                        child: Text(S.of(context).ok),
                        onPressed: () => Navigator.of(context).pop())
                  ],
                );
              });
        });
      }

      if (state is TransactionCreatedSuccessfully) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(S.of(context).sending),
                  content: Text(S.of(context).transaction_sent),
                  actions: <Widget>[
                    FlatButton(
                        child: Text(S.of(context).ok),
                        onPressed: () {
                          _addressController.text = '';
                          _cryptoAmountController.text = '';
                          Navigator.of(context).pop();
                        })
                  ],
                );
              });
        });
      }
    });

    _effectsInstalled = true;
  }
}
