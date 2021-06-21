# maps

My plan is to have a selection of shapefiles, probably just in CSV format, which can be used for making maps in R. The code used to generate the shapefiles will also be uploaded.

The features that I hope to include are listed in the [wiki for this project](https://github.com/brendanjodowd/maps/wiki).

## Maps data sources

The maps are based on open source maps from Ordnance Survey Ireland (OSi) and Ordnance Survey of Northern Ireland (OSNI), and manipulated using tools including the [rmapshaper](https://github.com/ateucher/rmapshaper) package. The OSi maps are available under the [Creative Commons Attribution 4.0 Licence](https://creativecommons.org/licenses/by/4.0/), while the OSNI maps are available under the [UK Open Government Licence](http://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/). Both of these licences allow the sharing and manipuation of this data provided that the source is acknowledged. 

Sources of shapefiles:

- [Local Electoral Areas](https://data.gov.ie/dataset/local-electoral-areas-osi-national-statutory-boundaries-generalised-20m1) - The ones in use since 2019
- [Local Electoral Areas 2015](https://data.gov.ie/dataset/local-electoral-areas-boundaries-generalised-100m-osi-national-administrative-boundaries-20151) - The ones in use at the time of the 2016 Census
- [Electoral Districts](https://data.gov.ie/dataset/cso-electoral-divisions-generalised-100m-osi-national-statistical-boundaries-2015)
- [NUTS2 Regions](https://data.gov.ie/dataset/nuts2-boundaries-generalised-100m-osi-national-statistical-boundaries-20151)
- [Northern Ireland outline](https://www.opendatani.gov.uk/dataset/osni-open-data-largescale-boundaries-ni-outline) - This one is from the Ordnance Survey of Northern Ireland. 
