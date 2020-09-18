import { Component } from '@angular/core';
import { NavController, LoadingController, ToastController, AlertController, Platform, PopoverController, ModalController } from 'ionic-angular';
import { Storage } from '@ionic/storage';
import { Geolocation } from '@ionic-native/geolocation';
import { HttpClient } from '@angular/common/http';
import { Device } from '@ionic-native/device';
import { AppRate } from '@ionic-native/app-rate';
import { ApiProvider } from '../../providers/api/api';

import { FeedbackPage } from './../feedback/feedback';
import { DailyReportsPage } from './../daily-reports/daily-reports';
import { FavoritesPage } from './../favorites/favorites';

@Component({
  selector: 'page-settings',
  templateUrl: 'settings.html',
})
export class SettingsPage {

  user: any = {};

  persistent_notifications_state: boolean = false;

  constructor(private navCtrl: NavController, private storage: Storage, private http: HttpClient, private loadingCtrl: LoadingController, 
    private alertCtrl: AlertController, private toastCtrl: ToastController, private geolocation: Geolocation, private platform: Platform, 
    private device: Device, private popoverCtrl: PopoverController, private modalCtrl: ModalController, public api: ApiProvider, 
    private appRate: AppRate,) {
      this.getPersistentNotificationsStatus();
  }


  // --------------------------------------------------------------------------------------------------------------------
  // Runs when the page has loaded. Fires only once
  // --------------------------------------------------------------------------------------------------------------------
  ionViewDidLoad() {
    this.getUserInfo();
  }


  // --------------------------------------------------------------------------------------------------------------------
  // Fires everytime page loads
  // --------------------------------------------------------------------------------------------------------------------
  ionViewDidEnter() {}


  // --------------------------------------------------------------------------------------------------------------------
  // Get User's info
  // --------------------------------------------------------------------------------------------------------------------
  getUserInfo() {
    this.storage.get('user_data').then((val) => {
      if(val && val != null && val != '') {
        this.user = val;
      }
    });
  }


  // --------------------------------------------------------------------------------------------------------------------
  // Store setting for persistent notifications
  // --------------------------------------------------------------------------------------------------------------------
  getPersistentNotificationsStatus() {
    this.storage.get('persistent_notifications').then((val) => {
      if(val && val != null && val != '') {
        this.persistent_notifications_state = val;
      }
    });
  }


  // --------------------------------------------------------------------------------------------------------------------
  // Go To Favorites Page
  // --------------------------------------------------------------------------------------------------------------------
  goToFavoritesPage() {
    this.navCtrl.push(FavoritesPage);
  }


  // --------------------------------------------------------------------------------------------------------------------
  // Go To Daily Reports Page
  // --------------------------------------------------------------------------------------------------------------------
  goToDailyReportsPage() {
    this.navCtrl.push(DailyReportsPage);
  }


  // --------------------------------------------------------------------------------------------------------------------
  // Go To Feedback Page
  // --------------------------------------------------------------------------------------------------------------------
  goToFeedbackPage() {
    this.navCtrl.push(FeedbackPage);
  }


  // --------------------------------------------------------------------------------------------------------------------
  // Rate App
  // --------------------------------------------------------------------------------------------------------------------
  rateApp() {
    // https://itunes.apple.com/ug/app/airqo-monitoring-air-quality/id1337573091?mt=8
    // https://play.google.com/store/apps/details?id=com.buzen.contract.airqoapp

    if(this.device.platform) {
      this.appRate.preferences.storeAppURL = {
        ios: 'id1337573091',
        android: 'market://details?id=com.buzen.contract.airqoapp',
      };
      
      this.appRate.promptForRating(true);
    }
  }


  // --------------------------------------------------------------------------------------------------------------------
  // Enable or Disable Persistent Notifications
  // --------------------------------------------------------------------------------------------------------------------
  enableDisablePersistentNotifications() {
    this.storage.set("persistent_notifications", this.persistent_notifications_state);
  }

}