#!/bin/bash
# **************************************************************************
# Creator: Remo Tomasi
#
# NOTE: we need to install jq, to use conv2htm.sh and phantomjs
#       and download rasterize.js
# **************************************************************************
# set the environment: these files as useful to save and use temporary datas

# test if directories DATAS, HTML, IMAGES don't exist and create them
if [ ! -d "DATAS" ]; then mkdir DATAS; fi
if [ ! -d "HTMLS" ]; then mkdir HTMLS; fi
if [ ! -d "IMAGES" ]; then mkdir IMAGES; fi
if [ ! -d "mexDATAS" ]; then mkdir mexDATAS; fi

if [ -e DATAS/wjson.json ]; then rm DATAS/wjson.json; fi
if [ -e DATAS/dati.csv ]; then rm DATAS/dati.csv; fi
if [ -e DATAS/finalDatas.csv ]; then rm DATAS/finalDatas.csv; fi
if [ -e DATAS/tmp.csv ]; then rm DATAS/tmp.csv; fi
if [ -e DATAS/weatherForecast.csv ]; then rm DATAS/weatherForecast.csv; fi
touch DATAS/wjson.json DATAS/dati.csv DATAS/finalDatas.csv

# Obtain today date
DATE=$(date +%d%m%Y)

echo -e "Insert latitude and longitude (separated by spaces, i.e.: 60.32 21.03)"
read par mer

# creation of the first line (columns)
echo -e " Date Time Temp DewP Hum Cloud Rain WindS WindDir WindDirDeg Sky Press Low Med High ChanceRain ChanceSnow ZeroLevel" > DATAS/finalDatas.csv

# download of json datas and save the wjson file
wget "http://ws1.metcheck.com/ENGINE/v9_0/json.asp?lat=$par&lon=$mer&lid=22553" 2>/dev/null -O - > DATAS/wjson.json

# loop to obtain infos from the json file: here we use jq
i=0
while [ $i -lt  `jq '.metcheckData.forecastLocation.forecast | length' DATAS/wjson.json` ]; do
  cat DATAS/wjson.json | jq --raw-output .metcheckData.forecastLocation.forecast["$i"].utcTime,.metcheckData.forecastLocation.forecast["$i"].temperature,.metcheckData.forecastLocation.forecast["$i"].dewpoint,.metcheckData.forecastLocation.forecast["$i"].humidity,.metcheckData.forecastLocation.forecast["$i"].totalcloud,.metcheckData.forecastLocation.forecast["$i"].rain,.metcheckData.forecastLocation.forecast["$i"].windspeed,.metcheckData.forecastLocation.forecast["$i"].windletter,.metcheckData.forecastLocation.forecast["$i"].winddirection,.metcheckData.forecastLocation.forecast["$i"].iconName,.metcheckData.forecastLocation.forecast["$i"].meansealevelpressure,.metcheckData.forecastLocation.forecast["$i"].lowcloud,.metcheckData.forecastLocation.forecast["$i"].medcloud,.metcheckData.forecastLocation.forecast["$i"].highcloud,.metcheckData.forecastLocation.forecast["$i"].chanceofrain,.metcheckData.forecastLocation.forecast["$i"].chanceofsnow,.metcheckData.forecastLocation.forecast["$i"].freezinglevel >> DATAS/dati.csv
  echo -e "\t" >> DATAS/dati.csv
  let i+=1
done

# finishing the informations formatting datas in various formats
cat DATAS/dati.csv | tr '\n' ',' | tr '\t' '\n' | tr ',' '\t' | sed 's/:00:00.00//g' | tr ' ' '-' | tr 'T' '\t' | tr '\t' ' ' >> DATAS/finalDatas.csv
sed -i '2d' DATAS/finalDatas.csv                                                    # first two lines
cat DATAS/finalDatas.csv | cut -d' ' -f2- > DATAS/tmp.csv                           # temporary file to eliminate first cloumn
cat DATAS/tmp.csv > DATAS/finalDatas.csv                                            # transfer in a new file
head -116 DATAS/finalDatas.csv > DATAS/weatherForecast.csv                           # 74: only 3 days of forecasting - 116: for 5 days
cp DATAS/weatherForecast.csv mexDATAS/weatherForecast_$par-$mer-$DATE.csv           # Archive csv in mexDATAS
awk 'BEGIN{FS=OFS=" "}{print $1,$2,$3,$4,$5,$6,$7,int($8*1.609),$9,$10,$11,$12,$13,$14,$15,$16,$17,$18 }' DATAS/weatherForecast.csv > DATAS/tmp.csv  # convert wind power from miles/h to km/h
sed -i 's/n 0 W/n WindS W/g' DATAS/tmp.csv                                          # column from 0 to WindS
cat DATAS/tmp.csv > DATAS/weatherForecast.csv
echo "Data file downloaded and formatted..."
./conv2htm.sh DATAS/weatherForecast.csv > HTMLS/weatherForecast.html                # csv to html conversion
xvfb-run --server-args="-screen 0, 1024x768x24" cutycapt --url=file://$PWD/HTMLS/weatherForecast.html --out=IMAGES/weatherForecastData.png
./graph.pg > IMAGES/weatherForecastGraph.png                                   # creating graph by gnuplot
./cloud.pg > IMAGES/weatherForecastCloud.png                                   # graph for clouds
./rain.pg > IMAGES/weatherForecastRain.png                                     # graph for rain
./pressureWind.pg > IMAGES/weatherForecastPressureWind.png                     # graph pressure/wind
./pressureZeroLevel.pg > IMAGES/weatherForecastPressureZeroLevel.png           # graph pressure/zerolevel
./tempDewPoint.pg > IMAGES/weatherForecastTempDewPoint.png                     # graph pressure/zerolevel
./wind.pg > IMAGES/weatherForecastWind.png                                 # graph pressure/zerolevel
./zeroTempDP.pg > IMAGES/weatherForecastZTDP.png                           # graph wind direction/power
# final image composition of the 3 previous graphs
# convert weatherForecastGraph.png weatherForecastCloud.png weatherForecastPressure.png +append weatherForecastFinal.png
convert \( IMAGES/weatherForecastGraph.png IMAGES/weatherForecastRain.png -append \) \( IMAGES/weatherForecastCloud.png IMAGES/weatherForecastPressureZeroLevel.png -append \) \( IMAGES/weatherForecastWind.png IMAGES/weatherForecastZTDP.png -append \) \( IMAGES/weatherForecastPressureWind.png -append \) +append IMAGES/weatherForecastFinal.png
rm DATAS/tmp.csv  # remove temporary or useless files
