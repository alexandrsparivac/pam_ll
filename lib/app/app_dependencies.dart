import '../data/local/asset_store_client.dart';
import '../data/datasources/store_remote_data_source.dart';
import '../data/repositories/store_repository_impl.dart';
import '../domain/usecases/commerce_usecases.dart';
import '../domain/usecases/store_usecases.dart';
import '../presentation/cubit/gem_store_cubit.dart';

GemStoreCubit createGemStoreCubit() {
  final repository = StoreRepositoryImpl(
    StoreRemoteDataSource(AssetStoreClient()),
  );
  return GemStoreCubit(
    getStore: GetStore(repository),
    setFavorite: SetFavorite(repository),
    addReview: AddReview(repository),
    deleteReview: DeleteReview(repository),
    manageCart: ManageCart(repository),
    saveProfile: SaveProfile(repository),
    placeOrder: PlaceOrder(repository),
    cancelOrder: CancelOrder(repository),
  );
}
