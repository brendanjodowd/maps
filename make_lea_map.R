library(tidyverse)
library(csodata)
library(sf)
library(broom)
library(rgdal)
library(maptools)
library(tmap)
library(sp)
library(readxl)
library(plotly)

# Read in LEA shapefile. Se value to 0/1.
lea_20 <- readOGR(dsn="LEA_shape_20" , layer= "35a9dae0-cac3-4dd4-8b82-ab9620d83b3a2020329-1-dre26o.cnhvf")
lea_20_df <- tidy(lea_20 , NUTS3="LE_ID" ) %>% mutate(value = if_else(id=="13100400" , 1 , 0))

# Have a quick look
ggplot(lea_20_df, aes(long, lat, group=group, fill=value)) + 
  geom_polygon(colour="white") + coord_fixed() 

# Take xy coords for re-projection
xy <- lea_20_df %>% select(long, lat) %>% rename(x = long , y=lat)

the_projection_string1 <- "+proj=tmerc +lat_0=53.5 +lon_0=-8 +k=0.99982 +x_0=600000 +y_0=750000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
the_projection_string2 <- "+proj=longlat"

# Make a new dataframe: lea_20_df
sputm <- SpatialPoints(cbind(xy$x,xy$y), proj4string=CRS(the_projection_string1))
spgeo <- spTransform(sputm, CRS(the_projection_string2))
new_coords <- data.frame(spgeo@coords)
lea_20_df_new <- cbind(lea_20_df , new_coords) %>% select(-long , -lat) %>% rename(long = coords.x1 , lat = coords.x2)

rm(sputm, spgeo, xy , new_coords)

# Have a quick look
ggplot(lea_20_df_new, aes(long, lat, group=group, fill=value)) + 
  geom_polygon(colour="white") + coord_quickmap() 

# Now bring in Northern Ireland shapefile.
# Cut out lots of points so that max distance between points is 100m
ni <- readOGR(dsn="NI_shape" , layer= "OSNI_Open_Data_-_Largescale_Boundaries_-_NI_Outline")
ni_df <- tidy(ni)%>% 
  mutate(lag_long = lag(long) , lag_lat = lag(lat)) %>% 
  mutate(lag_long = if_else(is.na(lag_long) , long , lag_long) , lag_lat = if_else(is.na(lag_lat) , lat , lag_lat)) %>% 
  mutate(dist = sqrt(((long-lag_long)^2) + ((lat-lag_lat)^2))) %>% 
  mutate(running_dist = cumsum(dist)) %>% 
  mutate(running_dist = floor(running_dist/100)) %>% 
  group_by(running_dist) %>% slice(1) %>% ungroup() %>% select(-dist , -running_dist , -lag_long, -lag_lat) %>% filter(hole==F)

# Have a look at NI map.
ggplot(ni_df, aes(long, lat, group=group)) + 
  geom_polygon(colour="white") +coord_fixed()

# Need to re-project NI. Create new dataframe ni_df_new
xy <- ni_df %>% select(long, lat) %>% rename(x = long , y=lat)

the_projection_string1 <- "+proj=tmerc +lat_0=53.5 +lon_0=-8 +k=1.000035 +x_0=200000 +y_0=250000 +a=6377340.189 +rf=299.3249646 +units=m +no_defs +type=crs"
the_projection_string2 <- "+proj=longlat"

sputm <- SpatialPoints(cbind(xy$x,xy$y), proj4string=CRS(the_projection_string1))
spgeo <- spTransform(sputm, CRS(the_projection_string2))
new_coords <- data.frame(spgeo@coords)
ni_df_new <- cbind(ni_df , new_coords) %>% select(-long , -lat) %>% rename(long = coords.x1 , lat = coords.x2) %>% 
  mutate(id="0") %>% mutate(group=paste(id , piece, sep=".")) %>% mutate(value=NA) 

# Have a quick look at the new, re-projected NI map
ggplot(ni_df_new, aes(long, lat, group=group, fill="grey")) + 
  geom_polygon(colour="white") +coord_quickmap()




# At this point you have a useable shapefile (as a dataframe), but no county names. Take these from the original shapefile.
# Create NUTS3 variable as well.
lea_details <- lea_20@data %>% select(LE_ID, COUNTY , PROVINCE) %>% rename(County=COUNTY)%>% 
  mutate(County = str_to_title(County)) %>% 
  mutate(NUTS3 = case_when(
    County=="Dublin"~"Dublin",
    County %in% c("Cork","Kerry")~"South-West",
    County %in% c("Galway","Roscommon", "Mayo")~"West",
    County %in% c("Louth","Meath", "Kildare" , "Wicklow")~"Mid-East",
    County %in% c("Wexford","Waterford", "Kilkenny" , "Carlow")~"South-East",
    County %in% c("Longford","Westmeath", "Offaly" , "Laois")~"Midlands",
    County %in% c("Clare","Limerick", "Tipperary")~"Mid-West",
    County %in% c("Donegal","Sligo", "Leitrim","Cavan","Monaghan")~"Border"
  ))



map <- rbind(lea_20_df_new , ni_df_new) %>% rename(LE_ID = id) %>% 
  left_join(. , lea_details) %>% mutate(NUTS3=if_else(is.na(NUTS3), "NI",NUTS3)) %>%  
  mutate(RAG = case_when(
    NUTS3 %in% c("South-East","Border","Midlands") ~ "Y",
    NUTS3 == "NI" ~ NA_character_,
    TRUE~"N"
  )) %>% mutate(RAG = factor(RAG , levels=c("Y","N")))

# Have a quick look at the whole map.
ggplot(map, aes(long, lat, group=group, fill=value)) + 
  geom_polygon(colour="white") + coord_quickmap() 
