/// All API endpoints, mapped 1:1 from the Laravel backend's routes/api.php.
/// Grouped exactly as they appear there so this file can be diffed against
/// the backend when routes change.
class ApiEndpoints {
  ApiEndpoints._();

  // ---- Public (no auth) ----
  static const login = '/auth/login';
  static const passwordEmail = '/auth/password/email';
  static const verifyPasswordToken = '/auth/password/verify/token'; // + /{token}
  static const resendOtp = '/auth/resend/otp';

  static const searchLocation = '/search/location';
  static const checkLocation = '/check/location';

  static const register = '/auth/register';
  static const registerVerify = '/auth/register/verify';
  static const registerChangeNumber = '/auth/register/change';
  static const checkEmail = '/auth/check/email';
  static const register2 = '/auth/register2';

  static const joinWaitingList = '/join/waiting-list';

  static const riderRegister = '/rider/register';
  static const riderRegisterVerify = '/rider/register/verify';
  static const riderRegisterChangeNumber = '/rider/register/change';

  static const merchantSearchOutlet = '/merchant/search/outlet';
  static const merchantRegister = '/merchant/register';
  static const merchantRegisterVerify = '/merchant/register/verify';
  static const merchantRegisterChangeNumber = '/merchant/register/change';

  static const banks = '/banks/index';
  static const countries = '/country/index';
  static const states = '/state/index';
  static const colors = '/color/index';

  static const setting = '/setting';

  // ---- Authenticated (shared across all roles) ----
  static const profileSaveDevice = '/profile/device';
  static const profileLogout = '/profile/logout';
  static const profileMe = '/profile/me';
  static const profileToken = '/profile/token';
  static const profileIAgree = '/profile/iagree';
  static const profileUpdatePassword = '/profile/password/update';
  static const profileMobileUpdate = '/profile/mobile/update';
  static const profileMobileVerify = '/profile/mobile/verify';
  static const profileActivityDetail = '/profile/activity/detail';

  static const coveredLocationIndex = '/profile/covered/locations';
  static const coveredLocationList = '/profile/covered/locations/lists';
  static const coveredLocationUpdate = '/profile/covered/locations/update';
  static const coveredLocationDelete = '/profile/covered/locations/delete';

  static const cityList = '/city/list';
  static const cityConfirm = '/city/confirm';

  static const helpTicketIndex = '/help/ticket';
  static const helpTicketDetail = '/help/ticket/detail';
  static const helpTicketOrderLists = '/help/ticket/order/lists';
  static const helpTicketStore = '/help/ticket/store';

  static const notificationIndex = '/notification/index';
  static const notificationUnread = '/notification/unread';
  static const notificationRead = '/notification/read';
  static const notificationReadAll = '/notification/read_all';
  static const notificationDelete = '/notification/delete';

  static const payment = '/payment';

  // ---- Customer ----
  static const customerHome = '/customer/home';
  static const customerAnnouncements = '/customer/home/announcements';
  static const customerProfile = '/customer/profile';
  static const customerProfileUpdate = '/customer/profile/update';
  static const customerProfileVerify = '/customer/profile/verify';

  static const customerAddressStore = '/customer/profile/address/store';
  static const customerAddressUpdate = '/customer/profile/address/update';
  static const customerAddressDelete = '/customer/profile/address/delete';

  static const customerBagQrcode = '/customer/profile/bag/qrcode';
  static const customerBagScan = '/customer/profile/bag/scan';
  static const customerBagPurchased = '/customer/profile/bag/purchased';
  static const customerBagAssigned = '/customer/profile/bag/assigned';
  static const customerOrderBagPlaceOrder = '/customer/order/bag/placeorder';

  static const customerSubscriptionPlaceOrder = '/customer/subscription/placeorder';
  static const customerSubscriptionCancel = '/customer/subscription/cancel';
  static const customerSubscriptionUpdate = '/customer/subscription/update';

  static const customerQrcodeAssign = '/customer/qrcode/assign';

  static const customerBookingCalculateRate = '/customer/booking/calculate/rate';
  static const customerBookingAddon = '/customer/booking/addon';
  static const customerBookingAddonList = '/customer/booking/addon/lists';
  static const customerBookingVoucher = '/customer/booking/voucher';
  static const customerBookingVoucherList = '/customer/booking/voucher/lists';
  static const customerBookingQrcodes = '/customer/booking/qrcodes';
  static const customerBookingSchedule = '/customer/booking/schedule';
  static const customerBookingInstructions = '/customer/booking/instructions';
  static const customerBookingBirthdayCheck = '/customer/booking/birthday/check';
  static const customerBookingAddonCheckDiscount = '/customer/booking/addon/check-discount';
  static const customerBookingInsuranceCheck = '/customer/booking/insurance/check';

  static const customerOrderActive = '/customer/order/active';
  static const customerOrderUpcoming = '/customer/order/upcoming';
  static const customerOrderDetail = '/customer/order/detail';
  static const customerOrderRating = '/customer/order/rating';

  // ---- Rider ----
  static const riderHome = '/rider/home';
  static const riderHomeDuty = '/rider/home/duty';
  static const riderProfile = '/rider/profile';
  static const riderProfileUpdate = '/rider/profile/update';
  static const riderOrderQrcodes = '/rider/order/qrcodes';
  static const riderOrderAccept = '/rider/order/accept';
  static const riderOrderPickup = '/rider/order/pickup';
  static const riderOrderPickupOutlet = '/rider/order/pickup/outlet';
  static const riderOrderDelivery = '/rider/order/delivery';
  static const riderOrderDeliveryUpload = '/rider/order/delivery/upload';
  static const riderScanQrcode = '/rider/scan/qrcode';
  static const riderOrderDetail = '/rider/order/detail';
  static const riderActivityHistory = '/rider/activity/history';
  static const riderReapplyUpdate = '/rider/re-apply/update';

  // ---- Merchant ----
  static const merchantHome = '/merchant/home';
  static const merchantHomeDuty = '/merchant/home/duty';
  static const merchantHomeCity = '/merchant/home/city';
  static const merchantProfile = '/merchant/profile';
  static const merchantProfileUpdate = '/merchant/profile/update';
  static const merchantOrderQrcodes = '/merchant/order/qrcodes';
  static const merchantOrderAccept = '/merchant/order/accept';
  static const merchantBagReceive = '/merchant/bag/receive';
  static const merchantWashComplete = '/merchant/wash/complete';
  static const merchantScanQrcode = '/merchant/scan/qrcode';
  static const merchantOrderDetail = '/merchant/order/detail';
  static const merchantActivityHistory = '/merchant/activity/history';
  static const merchantReapplyUpdate = '/merchant/re-apply/update';
}
