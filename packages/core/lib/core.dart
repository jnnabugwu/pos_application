/// Shared entities, repository contracts, and Firestore/Auth datasources
/// used by both `pos_app` and `manager_app`.
library;

export 'blocs/auth/auth_bloc.dart';
export 'blocs/auth/auth_event.dart';
export 'blocs/auth/auth_state.dart';

export 'di/register_core_dependencies.dart';

export 'entities/app_role.dart';
export 'entities/app_user.dart';
export 'entities/menu_item.dart';
export 'entities/order.dart';
export 'entities/order_line_item.dart';

export 'failures/failure.dart';
export 'failures/firebase_failure_mapper.dart';

export 'repositories/auth_repository.dart';
export 'repositories/menu_repository.dart';
export 'repositories/order_repository.dart';

export 'datasources/firebase_auth_datasource.dart';
export 'datasources/firestore_menu_datasource.dart';
export 'datasources/firestore_order_datasource.dart';
