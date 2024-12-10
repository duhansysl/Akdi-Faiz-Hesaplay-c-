#!/usr/bin/env bash
#
# ======================================================================
#
#  Copyright (C) 2024 duhansysl
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# ======================================================================
#
# shellcheck disable=SC2012,SC2024,SC2144
#
clear

# ============ Tanımlamalar ==============================
# Faiz oranları ve vergi
akdi_faiz_orani_kucuk=3.50   # % olarak  (0 TL ile 25.000 TL arası)
gecikme_faiz_orani_kucuk=3.80 # % olarak  (0 TL ile 25.000 TL arası)
akdi_faiz_orani_orta=4.25     # % olarak  (25.000 TL ile 150.000 TL arası)
gecikme_faiz_orani_orta=4.55  # % olarak  (25.000 TL ile 150.000 TL arası)
akdi_faiz_orani_buyuk=4.75    # % olarak  (150.000 TL üstü)
gecikme_faiz_orani_buyuk=5.05 # % olarak  (150.000 TL üstü)
vergi_orani=30                # %30 vergi oranı (%15 KKDF ve %15 BSMV toplamı)

# Asgari ödeme yüzdesi tanımlamaları
asgari_odeme_orani_kucuk=20   # %20 olarak (0 TL ile 25.000 TL arası)
asgari_odeme_orani_buyuk=40   # %40 olarak (25.000 TL üstü)

# ========================================================

# Kullanıcıdan gerekli bilgileri alın
echo "Kredi kartı borcu faiz hesaplama:"
echo
read -p "-> Kredi Kartı limitini (TL) girin: " kk_limit
read -p "-> Toplam borç miktarını (TL) girin: " toplam_borc
read -p "-> Ödenen miktarı (TL) girin: " odenen_miktar
read -p "-> Hesap kesim tarihi ile son ödeme tarihi arasındaki gün sayısını girin: " odeme_gun
read -p "-> Son ödeme tarihi ile bir sonraki hesap kesim tarihi arasındaki gün sayısını girin: " sonraki_gun
echo

# Limite göre faiz oranı ve asgari ödeme yüzdesini belirle
if [ $(echo "$kk_limit <= 25000" | bc) -eq 1 ]; then
    akdi_faiz=$akdi_faiz_orani_kucuk
    gecikme_faiz=$gecikme_faiz_orani_kucuk
    asgari_odeme_orani=$asgari_odeme_orani_kucuk
elif [ $(echo "$kk_limit <= 150000" | bc) -eq 1 ]; then
    akdi_faiz=$akdi_faiz_orani_orta
    gecikme_faiz=$gecikme_faiz_orani_orta
    asgari_odeme_orani=$asgari_odeme_orani_buyuk
elif [ $(echo "$kk_limit >= 150001" | bc) -eq 1 ]; then
    akdi_faiz=$akdi_faiz_orani_buyuk
    gecikme_faiz=$gecikme_faiz_orani_buyuk
    asgari_odeme_orani=$asgari_odeme_orani_buyuk
fi

# Hesaplamalar
asgari_tutar=$(echo "scale=2; $toplam_borc * $asgari_odeme_orani / 100" | bc)
odenen_asgari=$(echo "scale=2; $asgari_tutar - $odenen_miktar" | bc)
geriye_kalan_borc=$(echo "scale=2; $toplam_borc - $odenen_miktar" | bc)
if (( $(echo "$odenen_miktar < $asgari_tutar" | bc) )); then
geriye_kalan_asgari_borc=$(echo "scale=2; $asgari_tutar - $odenen_miktar" | bc)
fi

# Alışveriş faiz tutarı (hesap kesim ile son ödeme tarihi arası)
alisveris_faizi_birinci=$(echo "scale=2; $geriye_kalan_borc * $akdi_faiz / 100 * $odeme_gun / 30" | bc)

# Gecikme faiz tutarı (asgari tutarın ödenmeyen kısmı için son ödeme tarihinden sonra)
if (( $(echo "$odenen_miktar < $asgari_tutar" | bc) )); then
    gecikme_faizi=$(echo "scale=2; $geriye_kalan_asgari_borc * $gecikme_faiz * $sonraki_gun / 30" | bc)
else
    gecikme_faizi=0
	gecikme_faiz=0
fi

# Ödeme fazlaysa faiz hesaplamasını devre dışı bırak
if (( $(echo "$odenen_miktar > $toplam_borc" | bc) )); then
	geriye_kalan_borc=0
	alisveris_faizi_birinci=0
	alisveris_faizi_ikinci=0
	toplam_faiz=0
	vergi_tutari=0
	toplam_maliyet=0
fi

# Alışveriş faiz tutarı (son ödeme tarihinden sonraki günler için kalan borç)
alisveris_faizi_ikinci=$(echo "scale=2; $geriye_kalan_borc * $akdi_faiz / 100 * $sonraki_gun / 30" | bc)

# Toplam faiz tutarı
toplam_faiz=$(echo "scale=2; $alisveris_faizi_birinci + $alisveris_faizi_ikinci + $gecikme_faizi" | bc)

# Vergi tutarı
vergi_tutari=$(echo "scale=2; $toplam_faiz * $vergi_orani / 100" | bc)

# Toplam maliyet (faiz + vergi)
toplam_maliyet=$(echo "scale=2; $toplam_faiz + $vergi_tutari" | bc)

# Sonuçları göster
echo "==================== Faiz Hesaplama ===================="
echo
echo "-> Toplam borç miktarı                       : $toplam_borc TL"
echo "-> Asgari ödeme tutarı (%$asgari_odeme_orani)                 : $asgari_tutar TL"
echo "-> Ödenen miktar                             : $odenen_miktar TL"
echo "-> Kalan borç                                : $geriye_kalan_borc TL"
if (( $(echo "$odenen_miktar < $asgari_tutar" | bc) )); then
echo "-> Kalan asgari borç                         : $geriye_kalan_asgari_borc TL"
fi
echo "-> Alışveriş faizi (1. dönem) (%$akdi_faiz)        : $alisveris_faizi_birinci TL"
if (( $(echo "$odenen_miktar < $asgari_tutar" | bc) )); then
echo "-> Gecikme faizi (%$gecikme_faiz)                     : $gecikme_faizi TL"
fi
echo "-> Alışveriş faizi (2. dönem) (%$akdi_faiz)        : $alisveris_faizi_ikinci TL"
echo "-> Toplam faiz tutarı                        : $toplam_faiz TL"
echo "-> Vergi tutarı (%$vergi_orani)                        : $vergi_tutari TL"
echo "-> Toplam maliyet                            : $toplam_maliyet TL"
echo
echo "======================================================="