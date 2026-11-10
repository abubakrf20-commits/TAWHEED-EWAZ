import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/tool_identity.dart';
import 'package:tawheeed/features/personal/finance/finance_models.dart';

/// Identity colours of «دفتر مالی». Fixed hues so a kind is recognisable at a
/// glance in the hero bar, the timeline chips and the month chart; positive /
/// negative money still comes from the theme's success / danger tokens.
///
/// These four are the only hard-coded colours this feature is allowed to add —
/// the spec names them. Everything else must come from tokens.
const Color financeInstallmentColor = ToolIdentity.financeInstallment;
const Color financeChequeColor = ToolIdentity.financeCheque;
const Color financeLoanColor = ToolIdentity.financeLoan;
const Color financeOtherColor = ToolIdentity.financeOther;
const Color financeLedgerColor = ToolIdentity.financeLedger;

Color financeKindColor(ObligationKind kind) => switch (kind) {
      ObligationKind.installment => financeInstallmentColor,
      ObligationKind.cheque => financeChequeColor,
      ObligationKind.loan => financeLoanColor,
      ObligationKind.other => financeOtherColor,
    };

IconData financeKindIcon(ObligationKind kind) => switch (kind) {
      ObligationKind.installment => Icons.event_repeat_outlined,
      ObligationKind.cheque => Icons.receipt_long_outlined,
      ObligationKind.loan => Icons.account_balance_outlined,
      ObligationKind.other => Icons.more_horiz,
    };

/// Direction glyph for a ledger line.
IconData financeDirectionIcon(DebtDirection direction) =>
    direction == DebtDirection.owedToMe
        ? Icons.south_west
        : Icons.north_east;
