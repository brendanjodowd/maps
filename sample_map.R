library(cowplot)
library(tidyverse)
library(sf)

lea_137 <- st_read("https://raw.githubusercontent.com/brendanjodowd/maps/main/lea_137.geojson")

# hp_leas.csv is a file I made using LEA data from here: 
# http://trutzhaase.eu/deprivation-index/the-2016-pobal-hp-deprivation-index-for-small-areas/
# I deleted the NUTS data at the bottom of that Excel file and saved it as a csv.
hp <- read_csv("hp_leas.csv") %>% select(LEA_Name , HP2016rel) %>% rename(hp_name = LEA_Name)

map <- full_join( lea_137 , hp)

p <- ggplot(map , aes(fill=HP2016rel))+geom_sf()+theme_void()+
  geom_rect(xmin=-6.6, xmax=-6, ymin=53.2, ymax=53.6, fill=NA , size=0.6, colour="black")+
  geom_rect(xmin=-8.7, xmax=-8.2, ymin=51.78, ymax=51.97, fill=NA , size=0.6, colour="black")+
  theme(legend.justification = c(0.1), legend.position = c(0,0.8) , legend.key.size =unit(0.4,"cm"),
        legend.text = element_text(size=7), legend.title = element_text(size=8, vjust=3))+
  labs(fill="HP Deprivation Index")+
  scale_fill_distiller(palette = "Spectral" , direction = 1)

ggdraw(p)+draw_plot({p+coord_sf(xlim=c(-6.6,-6), ylim=c(53.2,53.6), expand=F)+
    theme(legend.position = "none")},
                    x=0.6, y=0.57, width=0.4, height=0.4)+
  draw_plot({p+coord_sf(xlim=c(-8.7,-8.2), ylim=c(51.78,51.97), expand=F)+
      theme(legend.position = "none")},
             x=0.65, y=0.0, width=0.24, height=0.24)
