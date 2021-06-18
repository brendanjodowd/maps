# A function to take a shapefile in dataframe form and apply a standard lat-long projection

fix_projection <- function(dataset , projection_string){
  
  # Take xy coords for re-projection
  xy <- dataset %>% select(long, lat) %>% rename(x = long , y=lat)
  
  
  # Make a new dataframe
  sputm <- SpatialPoints(cbind(xy$x,xy$y), proj4string=CRS(projection_string))
  spgeo <- spTransform(sputm, CRS("+proj=longlat"))
  new_coords <- data.frame(spgeo@coords)
  return_dataset <- cbind(dataset , new_coords) %>% select(-long , -lat) %>% rename(long = coords.x1 , lat = coords.x2)
  
  rm(sputm, spgeo, xy , new_coords)
  
  return(return_dataset)
}
