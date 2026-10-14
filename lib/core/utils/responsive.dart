import 'package:flutter/widgets.dart';

import '../config/app_constants.dart';

bool isDesktopWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;
