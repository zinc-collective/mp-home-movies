Home Movies
===========


## Building
The build is managed by xCode and CocoaPods;

Note that unless you are a Zinc Core Member, you may need to change your Team and other settings in the xCode target configuration.
### Prerequisites
- [Download the GoogleServices-Info.plist](https://console.firebase.google.com/u/0/project/homemovies-production/settings/general/ios:com.homemoviesapp.homemovies) or generate your own
- xCode 10.2 or greater
- [CocoaPods](https://guides.cocoapods.org/using/using-cocoapods.html) (and run `pod install`)


### Troubleshooting
- No account for team "5GGD34ZNFU" - This is the Zinc Core team account id; you'll want to Change the Build Settings -> Signing -> Development Team to your iOS Developer account.
- Build input file cannot be found: '.../GoogleService-Info.plist' - Zinc Core members may [Download the GoogleServices-Info.plist](https://console.firebase.google.com/u/0/project/homemovies-production/settings/general/ios:com.homemoviesapp.homemovies). Others are encouraged to [setup their own](https://firebase.google.com/docs/ios/setup) firebase project.