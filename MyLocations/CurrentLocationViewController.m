//
//  FirstViewController.m
//  MyLocations
//
//  Created by Stephen on 01/05/2014.
//  Copyright (c) 2014 vantech.com. All rights reserved.
//

#import "CurrentLocationViewController.h"

@interface CurrentLocationViewController ()

@end

@implementation CurrentLocationViewController {
	CLLocationManager *_locationManager;
	CLLocation *_location;
	BOOL _updatingLocation;
	NSError *_lastLocationError;
	CLGeocoder *_geocoder;
	CLPlacemark *_placemark;
	BOOL _performingReverseGeocoding;
	NSError *_lastGeocodingError;
}

-(id) initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super initWithCoder:aDecoder])){
		_locationManager = [[CLLocationManager alloc] init];
		_geocoder = [[CLGeocoder alloc] init];
	}
	return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self updateLabels];
	[self configureGetButton];
}

- (IBAction) getLocation:(id)sender {
	if (_updatingLocation) {
		[self stopLocationManager];
	} else {
		_location = nil;
		_lastLocationError = nil;
		_placemark = nil;
		_lastGeocodingError = nil;

		[self startLocationManager];
	}
	[self updateLabels];
	[self configureGetButton];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
	NSLog(@"didFailWithError %@", error);

	if (error.code == kCLErrorLocationUnknown) {
		return;
	}

	[self stopLocationManager];
	_lastLocationError= error;

	[self updateLabels];
	[self configureGetButton];
}

- (void) startLocationManager {
	if ([CLLocationManager locationServicesEnabled]) {
		_locationManager.delegate = self;
		_locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
		[_locationManager startUpdatingLocation];
		_updatingLocation = YES;

		[self performSelector:@selector(didTimeOut:) withObject:nil afterDelay:60];
	}
}

-(void)stopLocationManager{
	if (_updatingLocation) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(didTimeOut:) object:nil];
		[_locationManager stopUpdatingLocation];
		_locationManager.delegate = nil;
		_updatingLocation = NO;
	}
}

-(void)didTimeOut:(id)obj{
	NSLog(@"*** Timeout");

	if (_location == nil){
		[self stopLocationManager];
		_lastLocationError = [NSError errorWithDomain:@"MyLocationsErrorDomain" code:1 userInfo:nil];
		[self updateLabels];
		[self configureGetButton];
	}
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
	CLLocation *newLocation = [locations lastObject];
	NSLog(@"didUpdateLocations %@", newLocation);

	NSLog([NSString stringWithFormat:@"timeIntervalSinceNow - %f", [newLocation.timestamp timeIntervalSinceNow]]);
	if ([newLocation.timestamp timeIntervalSinceNow] < -5.0) {
		return;
	}

	NSLog([NSString stringWithFormat:@"horizontalAccuracy - %f", newLocation.horizontalAccuracy]);
	if (newLocation.horizontalAccuracy < 0) {
		return;
	}

	CLLocationDistance  distance = MAXFLOAT;
	if (_location != nil) {
		distance = [newLocation distanceFromLocation:_location];
	}

	NSLog([NSString stringWithFormat:@"_location.horizontalAccuracy - %f", _location.horizontalAccuracy]);
	if (_location == nil || _location.horizontalAccuracy >= newLocation.horizontalAccuracy) {
		_lastLocationError = nil;
		_location = newLocation;
		[self updateLabels];

		NSLog([NSString stringWithFormat:@"desiredAccuracy - %f", _locationManager.desiredAccuracy]);
		if (newLocation.horizontalAccuracy <= _locationManager.desiredAccuracy) {
			NSLog(@"*** We're done!");
			[self stopLocationManager];
			[self configureGetButton];

			if (distance > 0) {
				_performingReverseGeocoding = NO;
			}
		}

		if (!_performingReverseGeocoding) {
			NSLog(@"*** Going to geocode");

			_performingReverseGeocoding = YES;

			[_geocoder reverseGeocodeLocation:_location completionHandler:^(NSArray *placemarks, NSError *error){
				NSLog(@"*** Found placemarks: %@, error: %@", placemarks, error);
				_lastGeocodingError = error;
				_placemark = error == nil && [placemarks count] > 0 ? [placemarks lastObject] : nil;

				_performingReverseGeocoding = NO;
				[self updateLabels];
			}];
		}
	} else if (distance < 1.0) {
		NSTimeInterval timeInterval = [newLocation.timestamp timeIntervalSinceDate:_location.timestamp];
		if (timeInterval > 10){
			NSLog(@"*** Force done!");
			[self stopLocationManager];
			[self updateLabels];
			[self configureGetButton];
		}
	}
}

-(void)configureGetButton{
	if (_updatingLocation) {
		[self.getButton setTitle:@"Stop" forState:UIControlStateNormal];
	} else {
		[self.getButton setTitle:@"Get My Location" forState:UIControlStateNormal];
	}
}

-(NSString *)stringFromPlacemark:(CLPlacemark *)thePlacemark{
	NSLog(@"%@ %@ %@ %@ %@ %@", thePlacemark.subThoroughfare, thePlacemark.thoroughfare, thePlacemark.locality, thePlacemark.administrativeArea, thePlacemark.postalCode, thePlacemark.country);
	return [NSString stringWithFormat:@"%@ %@\n%@ %@ %@",
	                 thePlacemark.subThoroughfare,
	                 thePlacemark.thoroughfare,
					 thePlacemark.locality,
					 thePlacemark.administrativeArea,
					 thePlacemark.postalCode];
}

- (void)updateLabels
{
	if (_location != nil) {
		self.latitudeLabel.text = [NSString stringWithFormat: @"%.8f", _location.coordinate.latitude];
		self.longitudeLabel.text = [NSString stringWithFormat: @"%.8f", _location.coordinate.longitude];
		self.tagButton.hidden = NO;
		self.messageLabel.text = @"";
		if (_placemark != nil) {
			self.addressLabel.text = [self stringFromPlacemark:_placemark];
		} else if (_performingReverseGeocoding){
			self.addressLabel.text = @"Searching for Address...";
		} else if (_lastGeocodingError != nil) {
			self.addressLabel.text = @"Error Finding Address";
		} else {
			self.addressLabel.text = @"No Address Found";
		}
	} else {
		self.latitudeLabel.text = @"";
		self.longitudeLabel.text = @"";
		self.addressLabel.text = @"";
		self.tagButton.hidden = YES;

		NSString *statusMessage;
		if (_lastLocationError != nil) {
			if ([_lastLocationError.domain isEqualToString:kCLErrorDomain] && _lastLocationError.code == kCLErrorDenied) {
				statusMessage = @"Location Services Disabled";
			} else {
				statusMessage = @"Error Getting Location";
			}
		} else if (![CLLocationManager locationServicesEnabled]) {
			statusMessage = @"Location Services Disabled";
		} else if (_updatingLocation) {
			statusMessage = @"Searching...";
		} else {
			statusMessage = @"Press the Button to Start";
		}
		self.messageLabel.text = statusMessage;
	}
}
@end
