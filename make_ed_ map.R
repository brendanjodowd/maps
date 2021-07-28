# The 14 regions that don't match up to the CSO database are all around Cork City, 
# and are probably to do with the redrawing of Cork City's boundary. 
# They all have an ED_ID which is the same as a neighbouring ED (also having the same name)
# with a "19" added, 47277 and 4727719 for Rathcooney.
# So these pairs could probably be safely combined for matching up with CSO census data.
# These ones can be found by selecting the 14 EDs with an ED_ID string length of 7. Then you could 
# trim their last two digits, group by ED_ID and carry out st_union.



cso <- read_csv("E2013.20210716T150733.csv") %>%select(-STATISTIC) %>%  spread(Statistic, VALUE) %>% 
  rename(ed_code_cso = C02779V03348 , cso_name = 4 , cso_area=6, pop=7) %>% select(ed_code_cso ,cso_name , cso_area, pop)

map_shape <- st_read("Electoral_Divisions_-_OSi_National_Statutory_Boundaries_-_Generalised_20m.geojson")%>% 
  st_transform( "+proj=longlat" ) %>% rename(ed_map=ENGLISH) %>% 
  select(-GAEILGE, -CONTAE , -PROVINCE , -Shape__Area, -Shape__Length , -OBJECTID)

# Create working version of map. Group areas around Cork that were broken up due to change in City boundary.
ed_map <- map_shape %>% 
  mutate(ED_ID = if_else(str_length(ED_ID)==7 , str_sub(ED_ID , 1,5) , ED_ID)) %>% mutate(AREA=AREA/1000000) %>% 
  group_by(ED_ID) %>% summarise(geometry = st_union(geometry) , AREA = sum(AREA)) 

# After the union, it is just ED_ID and geometry so join with the original map to get rest of details. 
# Note that centroids and GUIDs might not be right.

ed_map <- left_join(ed_map , st_drop_geometry(map_shape)  %>% select( -AREA , -GUID))

# This just has ed_code_cso and ED_ID
ed_lookup <- read_csv("ECAD_2017_TO_CSO_ED_LOOKUP.csv") %>% 
  mutate(ED_ID = as.character(DED_ID)) %>% 
  rename(ed_code_cso = CSOED_3409) %>% select(ed_code_cso , ED_ID)


ed_map2 <- full_join(ed_map , ed_lookup) 
# This is a perfect match, but it doesn't match perfectly with cso yet. 
# It is created to find the loose bits.


# create a dataset of bits in cso that have no match in the map.
loose_bits <- anti_join( cso , ed_map2) %>% # join happens by ed_code_cso
  mutate(ed_map = str_to_upper(str_extract(cso_name , "(?<=\\d ).*(?=,)")) ) %>% 
  mutate(ed_map = case_when(
    ed_map=="CEANNÚIGH" ~ "CANUIG",
    ed_map=="DOIRE IANNA" ~ "DERRIANA",
    ed_map=="MÁISTIR GAOITHE" ~ "MASTERGEEHY",
    ed_map=="AGHAVOGHILL" ~ "AGHAVOGHIL",
    ed_map=="LOUGHILL" ~ "LOUGHIL",
    T~ed_map
  ))

# now these can be fully matched to ed_map, but care has to be taken that the matches are done only to the records that don't match cso.

# this join is by ed_code_cso, which is then renamed (kept in case)
loose_bits <- full_join(loose_bits , anti_join(ed_map2 , cso) %>% rename(double_code = ed_code_cso) ) %>% filter(cso_name !="State")
# this join is by ed_map.

rm(ed_map2)

# so we have a link between ed_map and cso for a collection of places that otherwise wouldn't link. 

# Filter out the places with the double cso code (separated by /), these are added in loose_bits.
new_lookup <- ed_lookup %>% filter(!str_detect(ed_code_cso , "/")) 
# Now add loose_bits
new_lookup <- bind_rows(new_lookup , loose_bits %>% select(ed_code_cso, ED_ID , double_code))
rm(loose_bits, ed_lookup)
# this is the crucial new lookup. It should be possible now to go straight from map to cso.
new_lookup <- left_join(new_lookup , cso) %>% select(ED_ID , cso_name) 
# Here we add it on to the map.

ed_3441 <- full_join(ed_map, new_lookup) %>% rename(ED=ed_map) # perfect!

# Let's try it out by bringing in a cso dataset again. 
cso_new <- read_csv("E2013.20210716T150733.csv") %>%select(-STATISTIC) %>%  spread(Statistic, VALUE) %>% 
  rename(ed_code_cso = C02779V03348 , cso_name = 4 , cso_area=6, pop=7)

# Join them (no problems!)
some_map <- full_join(ed_3441 , cso_new) # perfect, the State is one extra line 3441+1=3442

# And plot!
#ggplot(filter(some_map , cso_name!="State") , aes(fill=pop))+geom_sf()

# Would still like to add NI and remove Shannon. 

ed_3441 <- ms_clip(ed_3441 , clip=shannon)
#ggplot(ed_3441)+geom_sf()

ni_eds <- ni %>% st_difference( ed_map %>% ungroup() %>% summarise(geometry=st_union(geometry)) ) %>% 
  select(geometry , AREA) %>% mutate(ED_ID = "NI" , ) %>% mutate(ED="NI" , cso_name = "NI")

#ggplot(ni_eds)+geom_sf()

ed_3441 <- bind_rows(ed_3441 , ni_eds)

rm(ni_eds)

ggplot(ed_3441 , aes(fill=ED))+geom_sf()  + theme_void()+ theme(legend.position = "none")

st_write(ed_3441 , "ed_3441.geojson")















cso_3409 <- read_csv("NPA04.20210721T110744.csv") %>% rename(cso_name = 8, cso_ed = C03514V04244) %>% select(cso_name , cso_ed) %>% 
  filter(cso_name !="State") %>% mutate(cso_name = str_replace(cso_name , "^001  Carlow Urban" , "001 Carlow Urban"))


ed_3409 <- inner_join( ed_3441 , cso_3409) # 3377, join by cso_name

only_old <- anti_join(ed_3441 , cso_3409 ) %>% mutate(bit = str_extract(cso_name , "(?<=\\d{3}\\s).*(?=,)"))

only_new <- anti_join( cso_3409 , ed_3441 ) %>% rbind(.,.) %>% arrange(cso_name) %>% 
  mutate(bit = trimws(str_remove(cso_name , "999"))) %>% 
  mutate(bit = if_else(row_number()%%2==1 , str_extract(bit , "^.*(?=/)") , str_extract(bit ,"(?<=/).*"))) %>% 
  mutate(bit = trimws(bit))

double_matches_3409 <- inner_join(only_old %>% rename(other_cso_name = cso_name) , only_new , by="bit") %>%  # 64 / 32
  arrange(cso_name , bit)

rm(only_new , only_old)

double_matches_3409 <- double_matches_3409 %>% group_by(cso_name ,cso_ed ,COUNTY ) %>% 
  summarise(geometry = st_union(geometry) , AREA=sum(AREA) 
            , ED_ID = paste0(ED_ID ,collapse = " / ")  , ED = paste0(ED ,collapse = " / ") 
            )


ed_3409 <- bind_rows(ed_3409 ,double_matches_3409 , ed_3441 %>% filter(ED=="NI")) 

rm(double_matches_3409)

ggplot(ed_3409 )+geom_sf()  
#ggplot(ed_3409 , aes(fill=ED))+geom_sf()  + theme_void()+ theme(legend.position = "none")



hp_ed <- read_csv("HP-Index-2006-2016-HP-Index-Scores-by-ID06b2.csv") %>% select(ID06 , ED_Name , HP2016rel)

# Most HP EDs can be joined to our map using ID06, which we will call HP_ID. 

# Create HP_ID. In most cases it is correct, but in some cases it's not.
ed_3409 <- ed_3409 %>% mutate(HP_ID = as.integer(cso_ed))

hp_only <- anti_join(hp_ed %>% rename(HP_ID=ID06) , ed_3409) %>% 
  mutate(ED_Name  = if_else(str_detect(ED_Name , "Gaoithe"), "Ceannúigh/Máistir Gaoithe" , ED_Name)) %>% 
  mutate(A = str_split(ED_Name , "/", simplify = T)[,1])%>% 
  mutate(B = str_split(ED_Name , "/", simplify = T)[,2]) %>% 
  mutate(first = if_else(A<B , A , B)) %>% 
  mutate(second = if_else(A<B , B , A)) %>% select(-A, -B) %>% 
  mutate(pattern = str_c(first , second , sep=" // ")) %>% select(-first , -second) %>% 
  mutate(pattern = str_replace(pattern, "Brishna", "Brisha")) %>% 
  mutate(pattern = str_replace(pattern, "Daoire", "Doire")) %>% 
  mutate(pattern = str_replace(pattern, "Drumakeever", "Dunmakeever")) %>% 
  mutate(pattern = str_remove(pattern, " \\(scarriff rd\\)" )) %>% rename(ID06 = HP_ID)
cso_only <- anti_join(ed_3409 , hp_ed %>% rename(HP_ID=ID06) )%>% 
  mutate(A = trimws(str_remove(str_split(cso_name , "/", simplify = T)[,1] ,"999")))%>% 
  mutate(B = trimws(str_split(cso_name , "/", simplify = T)[,2])) %>% 
  mutate(first = if_else(A<B , A , B)) %>% 
  mutate(second = if_else(A<B , B , A)) %>% select(-A, -B) %>% 
  mutate(pattern = str_c(first , second , sep=" // ")) 

last_matches <- inner_join(hp_only ,cso_only) %>% select(ID06 , HP_ID)

ed_3409 <- left_join(ed_3409 , last_matches) %>% 
  mutate(HP_ID = if_else(is.na(ID06), HP_ID , ID06))


st_write(ed_3409 , "ed_3409.geojson")
