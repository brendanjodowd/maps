# this makes two dataframes, LEA_137 and LEA_166, which are shapes for local electoral areas
# Maps for counties, admin_areas, NUTS2 and NUTS3 can be produced from these using group_by and summarise,
# see example with counties below.


library(tidyverse)
library(rmapshaper)
library(sf)
library(csodata)
library(tmap)



# Bring in shapefile, correct projection, create new regional variables.

lea_166 <- st_read("Local_Electoral_Areas_-_OSi_National_Statutory_Boundaries_-_Generalised_20m.geojson") %>% 
  st_transform( "+proj=longlat" ) %>% 
  select(LE_ID , ENGLISH , COUNTY ,AREA, geometry)%>% 
  rename(LEA=ENGLISH) %>% 
  mutate(NUTS3 = case_when(
    COUNTY=="DUBLIN"~"Dublin",
    COUNTY %in% c("CORK","KERRY")~"South-West",
    COUNTY %in% c("GALWAY","ROSCOMMON", "MAYO")~"West",
    COUNTY %in% c("LOUTH","MEATH", "KILDARE" , "WICKLOW")~"Mid-East",
    COUNTY %in% c("WEXFORD","WATERFORD", "KILKENNY" , "CARLOW")~"South-East",
    COUNTY %in% c("LONGFORD","WESTMEATH", "OFFALY" , "LAOIS")~"Midlands",
    COUNTY %in% c("CLARE","LIMERICK", "TIPPERARY")~"Mid-West",
    COUNTY %in% c("DONEGAL","SLIGO", "LEITRIM","CAVAN","MONAGHAN")~"Border"
  )) %>% 
  mutate(NUTS2 = case_when(
    NUTS3 %in% c("Dublin" , "Mid-East" , "Midlands")~"Eastern and Midland",
    NUTS3 %in% c("Border" , "West" )~"Northern and Western",
    T ~ "Southern"
  )) %>% 
  mutate(ADMIN_AREA = case_when(
    !(COUNTY %in% c("GALWAY" ,"DUBLIN", "CORK")) ~ COUNTY ,
    str_detect(LEA , "CORK CITY") ~ "CORK CITY",
    str_detect(LEA , "GALWAY CITY") ~ "GALWAY CITY",
    str_detect(LEA, "BALLYMUN|CABRA|BALLYFERMOT|KIMMAGE|PEMBROKE|INNER CITY|CLONTARF|DONAGHMEDE|ARTANE")~"DUBLIN CITY",
    str_detect(LEA, "STILLORGAN|DUNDRUM|GLENCULLEN|KILLINEY|LAOGHAIRE|BLACKROCK")~"DÚN LAOGHAIRE-RATHDOWN",
    str_detect(LEA, "RUSH|SWORDS|BLANCHARDSTOWN|CASTLEKNOCK|HOWTH|BALBRIGGAN|ONGAR")~"FINGAL",
    str_detect(LEA, "LUCAN|TALLAGHT|RATHFARNHAM|FIRHOUSE|CLONDALKIN|PALMERSTOWN")~"SOUTH DUBLIN",
    COUNTY=="CORK" ~ "CORK COUNTY",
    COUNTY=="GALWAY" ~ "GALWAY COUNTY",
  ))


object.size(lea_166) # 2.9MB
plot(lea_166 )


# How to use it to create a map of a broader region.
county_sf <- lea_166 %>% group_by(COUNTY) %>% summarise(geometry = st_union(geometry) , AREA=sum(AREA))
plot(county_sf)
ggplot(county_sf)+geom_sf()

# Read in coast for the Shannon estuary
# shannon <- st_read("Landmask_-_OSi_National_250k_Map_of_Ireland.geojson") %>% 
#   st_transform( "+proj=longlat" ) %>% st_union() %>% select(geometry)


extra_box = st_sfc(st_polygon(list(cbind(c(-11,-11,-5.5,-5.5,-11,-11,-8.55,-8.55,-11),c(52.84,56,56,51,51,52.51,52.51,52.84,52.84)))) 
                   , crs = "+proj=longlat")


shannon <- st_read("Landmask_-_OSi_National_250k_Map_of_Ireland.geojson") %>% 
  st_transform( "+proj=longlat" ) %>% ms_clip(bbox = c(-10,52.5,-8.5,52.85)) %>% 
  st_union(extra_box ) %>% st_union() %>% st_sf()
object.size(shannon) # 1.2 MB
plot(shannon )


lea_166 <- ms_clip(lea_166 , clip=shannon)
object.size(lea_166) # 2.95 MB

ggplot(st_crop(lea_166 , xmin=-10.5 ,xmax=-8 ,ymin=52.4, ymax=53) , aes(fill=LE_ID)) + geom_sf() 


# Bring in NI shapefile and prep it so that it's compatible with the LEA shapefile
ni <- st_read("OSNI_Open_Data_-_Largescale_Boundaries_-_County_Boundaries_.geojson")%>% 
  st_transform( "+proj=longlat" ) %>% ms_simplify() %>% mutate(LE_ID = "NI") %>% 
  group_by(LE_ID) %>% 
  summarise(geometry = st_union(geometry) , AREA = sum(Area_SqKM)*1000000) %>% 
  mutate(LEA="NI" ,COUNTY="NI" ,NUTS3="NI", NUTS2="NI" )

object.size(ni) # 339 kB
plot(ni)


lea_166 <- rbind(lea_166  , mutate(ni , ADMIN_AREA ="NI" ))
plot(lea_166)


ggplot(st_crop(lea_166 , xmin=-9 ,xmax=-7.5 ,ymin=54, ymax=55) , aes(fill=LE_ID)) + geom_sf() 


# This is a dataset which includes the map names and the names used in CSO statbank files.
lea_names <- lea_166 %>% select(LEA , COUNTY )  %>%  st_drop_geometry() %>% mutate(cso_name=LEA) %>%  
  mutate(cso_name = str_to_title(str_remove(cso_name , "(\\s|-)LEA-\\d")) , COUNTY=str_to_title(COUNTY)) %>% 
  filter(cso_name!="Ni") %>% 
  mutate(COUNTY = if_else(COUNTY %in% c("Cork" ,"Galway") & !str_detect(cso_name , "City")  , str_c(COUNTY , " County") , COUNTY )) %>% 
  mutate(COUNTY = if_else(COUNTY %in% c("Cork" ,"Galway") & str_detect(cso_name , "City")  , str_c(COUNTY , " City") , COUNTY )) %>% 
  mutate(COUNTY = case_when(
    str_detect(cso_name, "Ballymun|Cabra|Ballyfermot|Kimmage|Pembroke|Inner City|Clontarf|Donaghmede|Artane")~"Dublin City",
    str_detect(cso_name, "Stillorgan|Dundrum|Glencullen|Killiney|Laoghaire|Blackrock")~"Dún Laoghaire-Rathdown",
    str_detect(cso_name, "Rush|Swords|Blanchardstown|Castleknock|Howth|Balbriggan|Ongar")~"Fingal",
    str_detect(cso_name, "Lucan|Tallaght|Rathfarnham|Firhouse|Clondalkin|Palmerstown")~"South Dublin",
    T ~ COUNTY
  )) %>% 
  mutate(cso_name = str_c(trimws(cso_name) , COUNTY , sep=", ")) %>% select(-COUNTY) %>% 
  mutate(cso_name = str_to_title(cso_name)) %>% 
  mutate(cso_name = str_replace(cso_name , " - " , "-")) %>% 
  mutate(cso_name = str_replace(cso_name , " -M" , "-M")) %>% 
  mutate(cso_name = str_replace(cso_name , "  " , "-"))  

lea_166 <- full_join(lea_166 , lea_names) %>% 
  # now to tidy up the original (map) LEA names
  mutate(LEA = str_to_title(str_remove(LEA , "(\\s|-)LEA-\\d")) ) %>% 
  mutate(LEA = str_replace(LEA , "( - )|( -)|(- )|(  )" , "-")   ) %>% 
  mutate(LEA = str_replace(LEA , "-In-" , "-in-")   ) %>% 
  mutate(LEA = str_replace(LEA , "-On-" , "-on-")   ) %>% 
  mutate(LEA = str_replace(LEA , "^Ni$" , "NI")   ) 




lea_137 <- st_read("Local_Electoral_Areas_Boundaries_Generalised_100m_-_OSi_National_Administrative_Boundaries_-_2015.geojson")%>% 
  st_transform( "+proj=longlat" ) %>% 
  select(GUID, LE_ID , LE_ENGLISH, COUNTY , Shape__Area) %>% rename(AREA=Shape__Area , LEA=LE_ENGLISH) %>% 
  mutate(NUTS3 = case_when(
    COUNTY=="Dublin"~"Dublin",
    COUNTY %in% c("Cork","Kerry")~"South-West",
    COUNTY %in% c("Galway","Roscommon", "Mayo")~"West",
    COUNTY %in% c("Louth","Meath", "Kildare" , "Wicklow")~"Mid-East",
    COUNTY %in% c("Wexford","Waterford", "Kilkenny" , "Carlow")~"South-East",
    COUNTY %in% c("Longford","Westmeath", "Offaly" , "Laois")~"Midlands",
    COUNTY %in% c("Clare","Limerick", "Tipperary")~"Mid-West",
    COUNTY %in% c("Donegal","Sligo", "Leitrim","Cavan","Monaghan")~"Border"
  )) %>% 
  mutate(NUTS2 = case_when(
    NUTS3 %in% c("Dublin" , "Mid-East" , "Midlands")~"Eastern and Midland",
    NUTS3 %in% c("Border" , "West" )~"Northern and Western",
    T ~ "Southern"
  ))



lea_137 <- rbind(ms_clip(lea_137 , clip=shannon) , mutate(ni  , GUID="NI"))
plot(lea_137)


lea_names <- st_drop_geometry(lea_137) %>% select(COUNTY , LEA) %>% filter(LEA!="NI") %>% 
  mutate(cso_name = trimws(str_to_title(str_remove(LEA , "\\(\\d{1,2}\\)"))) , COUNTY=str_to_title(COUNTY)) %>% 
  mutate(COUNTY = case_when(
    str_detect(cso_name, "Ballymun|Cabra|Ballyfermot|Kimmage|Pembroke|Inner City|Clontarf|Donaghmede|Artane|Rathgar")~"Dublin City",
    str_detect(cso_name, "Stillorgan|Dundrum|Glencullen|Killiney|Laoghaire|Blackrock")~"Dún Laoghaire-Rathdown",
    str_detect(cso_name, "Rush|Swords|Blanchardstown|Castleknock|Howth|Balbriggan|Ongar|Mulhuddart")~"Fingal",
    str_detect(cso_name, "Lucan|Tallaght|Rathfarnham|Firhouse|Clondalkin|Palmerstown|Templeogue")~"South Dublin",
    str_detect(cso_name, "Galway City")~"Galway City",
    str_detect(cso_name, "Cork City")~"Cork City",
    T ~ COUNTY
  )) %>% 
  mutate(cso_name = str_c(cso_name , COUNTY ,sep=", ")) %>% 
  select(-COUNTY) %>% 
  # things that are common to CSO and HP
  mutate(cso_name=str_replace(cso_name , "—" , "-")) %>% 
  mutate(cso_name=str_replace(cso_name , "City North " , "City North-")) %>% 
  mutate(cso_name=str_replace(cso_name , "City South " , "City South-")) %>% 
  mutate(cso_name=str_replace(cso_name , "Dun Laoghaire" , "Dún Laoghaire")) %>% 
  mutate(cso_name=str_replace(cso_name , "-In-" , "-in-")) %>% 
  mutate(cso_name=str_replace(cso_name , "-On-" , "-on-")) %>% 
  mutate(cso_name=str_replace(cso_name , "South And" , "South and")) %>% 
  mutate(cso_name=str_replace(cso_name , "Athenry-Oranmore" , "Athenry - Oranmore")) %>% 
  mutate(cso_name=str_replace(cso_name , "Sandyford, " , "Sandyford,")) %>%  # This is a really dumb one, removing space before county.
  
  mutate(hp_name = str_remove(cso_name , ",.*$")) %>% 
  
  # EDITS for CSO only
  mutate(cso_name=str_replace(cso_name , "Dundalk - " , "Dundalk ")) %>% 
  mutate(cso_name=str_replace(cso_name , "Cobh" , "Cóbh")) %>%  
  mutate(cso_name=str_replace(cso_name , "Cork City" , "Cork")) %>% 
  mutate(cso_name=str_replace(cso_name , "Ballyfermot - Drimnagh" , "Ballyfermot-Drimnagh")) %>% 
  mutate(cso_name=str_replace(cso_name , "Conamara," , "Connemara,")) %>% 
  mutate(cso_name=str_replace(cso_name , "Tallaght " , "Tallaght - ")) %>% 
  
  # EDITS for HP only
  mutate(hp_name = str_replace(hp_name , "Celbridge - Leixlip" , "Celbridge-Leixlip")) %>% 
  mutate(hp_name = str_replace(hp_name , "Ratoath" , "Rathoath")) %>% 
  mutate(hp_name = str_replace(hp_name , "Howth - Malahide" , "Howth-Malahide"))  %>% 
  mutate(hp_name = str_replace(hp_name , "Bailieborough" , "Baillieborough")) %>% 
  mutate(hp_name = str_replace(hp_name , "Laytown - Bettystown" , "Slane")) %>% 
  mutate(hp_name = str_replace(hp_name , "Castleblayney" , "Castleblaney")) %>% 
  mutate(hp_name = str_replace(hp_name , "Castlecomer" , "Castlecomber")) %>% 
  mutate(hp_name = str_replace(hp_name , "Kilkenny City-" , "Kilkenny City ")) %>% 
  mutate(hp_name = str_replace(hp_name , "Howth-Malahide" , "Howth - Malahide")) %>% 
  mutate(hp_name = str_replace(hp_name , "Borris-in" , "Borris-on")) %>% 
  mutate(hp_name = str_replace(hp_name , "Muinebeag" , "Muinbeag")) %>% 
  mutate(hp_name = str_replace(hp_name , "Glencullen-Sandyford" , "Glencullen/Sandyford")) %>% 
  mutate(hp_name = str_replace(hp_name , "Pembroke" , "Pembrooke")) %>% 
  mutate(hp_name = str_replace(hp_name , "Cork City North-Central" , "Cork City North -Central")) %>% # Another dumb one.
  mutate(hp_name = str_replace(hp_name , "North Inner" , "North - Inner")) %>% 
  mutate(hp_name = case_when(
    hp_name=="Athlone" & str_detect(cso_name , "Roscommon") ~ "Athlone (R)",
    hp_name=="Athlone"  ~ "Athlone (WM)",
    T ~ hp_name
    ))


# now to tidy up the original (map) LEA names
lea_137 <- full_join(lea_137  , lea_names) %>% 
  mutate(LEA = trimws(str_to_title(str_remove(LEA , "\\(\\d{1,2}\\)")))) %>% 
  mutate(LEA=str_replace(LEA , "—" , "-")) %>% 
  mutate(LEA=str_replace(LEA , " - " , "-")) %>% 
  mutate(LEA=str_replace(LEA , "Dun Laoghaire" , "Dún Laoghaire")) %>% 
  mutate(LEA=str_replace(LEA , "-In-" , "-in-")) %>% 
  mutate(LEA=str_replace(LEA , "-On-" , "-on-")) %>% 
  mutate(LEA=str_replace(LEA , " And " , " and ")) %>% 
  mutate(LEA=str_replace(LEA , "^Ni$" , "NI"))

