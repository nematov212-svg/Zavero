// GENERATED PRESET FOOD & DRINK LIBRARY FOR ZAVERO POS
import 'dart:async';
import 'package:flutter/material.dart';

const Color kYellow = Color(0xFFFFC107);
const Color kDarkYellow = Color(0xFFFFA000);

class PresetFoodItem {
  final String title;
  final String url;
  final String? subtitle;
  final String? keywords;
  final String? brand;
  final String? volume;


  const PresetFoodItem({
    required this.title,
    required this.url,
    this.subtitle,
    this.keywords,
    this.brand,
    this.volume,
  });
}


class PresetFoodCategory {
  final String title;
  final IconData icon;
  final List<PresetFoodItem> items;

  const PresetFoodCategory({
    required this.title,
    required this.icon,
    required this.items,
  });

  List<String> get images => items.map((e) => e.url).toList();
}


const List<PresetFoodCategory> presetFoodLibraries = [
  PresetFoodCategory(
    title: 'Shaurma',
    icon: Icons.lunch_dining_rounded,
    items: [
      PresetFoodItem(
        title: 'Klassik Shaurma',
        subtitle: 'Go\'shtli va qarsildoq',
        url: 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=600&auto=format&fit=crop&q=80',
        keywords: 'shaurma, shawarma, шаурма, klassik, go\'sht',
      ),
      PresetFoodItem(
        title: 'Katta Shaurma (Max)',
        subtitle: 'Katta porsiya go\'shtli',
        url: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&auto=format&fit=crop&q=80',
        keywords: 'shaurma, big, max, katta, шаурма',
      ),
      PresetFoodItem(
        title: 'Tovuqli Shaurma',
        subtitle: 'Mayin tovuq go\'shti',
        url: 'https://images.unsplash.com/photo-1561651823-34feb02250e4?w=600&auto=format&fit=crop&q=80',
        keywords: 'tovuq, chicken, куриная шаурма, shaurma',
      ),
      PresetFoodItem(
        title: 'Pishloqli Shaurma',
        subtitle: 'Eritilgan mozzarella pishloq',
        url: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80',
        keywords: 'pishloq, cheese, сырная шаурма, mozzarella',
      ),
      PresetFoodItem(
        title: 'Tandir Shaurma',
        subtitle: 'Tandirda qizargan qarsildoq',
        url: 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600&auto=format&fit=crop&q=80',
        keywords: 'tandir, тандыр, shaurma, tandirda',
      ),
      PresetFoodItem(
        title: 'Achchiq Shaurma (Hot)',
        subtitle: 'Jalapeno va achchiq sous',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
        keywords: 'achchiq, hot, spicy, острый, jalapeno, shaurma',
      ),
      PresetFoodItem(
        title: 'Mini Shaurma',
        subtitle: 'Kichik porsiya yengil',
        url: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=600&auto=format&fit=crop&q=80',
        keywords: 'mini, kichik, мини шаурма, shaurma',
      ),
      PresetFoodItem(
        title: 'Arabcha Shaurma',
        subtitle: 'Maxsus arab ziravorlari',
        url: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80',
        keywords: 'arabcha, arabic, арабская шаурма, ziravor',
      ),
      PresetFoodItem(
        title: 'Doner Shaurma',
        subtitle: 'Baton nonda shirador go\'sht',
        url: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=600&auto=format&fit=crop&q=80',
        keywords: 'doner, döner, донер, baton, go\'sht',
      ),
      PresetFoodItem(
        title: 'Shaurma Pita',
        subtitle: 'Yumshoq pita nonida',
        url: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
        keywords: 'pita, пита, shaurma pita, non',
      ),
      PresetFoodItem(
        title: 'Shaurma Porsiya',
        subtitle: 'Likopchada fri va salat bilan',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        keywords: 'porsiya, tarelkada, fri, tarelka shaurma',
      ),
      PresetFoodItem(
        title: 'Assorti Shaurma',
        subtitle: 'Mol va tovuq go\'shti jamlanmasi',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
        keywords: 'assorti, mix, mol, tovuq, ассорти',
      ),
      PresetFoodItem(
        title: 'Zavero Special Shaurma',
        subtitle: 'Zavero mualliflik retsepti',
        url: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80',
        keywords: 'special, zavero, фирменная шаурма',
      ),
      PresetFoodItem(
        title: 'Shaurma Box',
        subtitle: 'Maxsus qutida fri bilan set',
        url: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80',
        keywords: 'box, boks, бокс, set, fri',
      ),
      PresetFoodItem(
        title: 'Qo\'ziqorinli Shaurma',
        subtitle: 'Shampinyon va oq sous',
        url: 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop&q=80',
        keywords: 'qo\'ziqorin, mushroom, грибы, грибная',
      ),
      PresetFoodItem(
        title: 'Double Shaurma',
        subtitle: 'Ikki hissa mol go\'shti',
        url: 'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?w=600&auto=format&fit=crop&q=80',
        keywords: 'double, 2x, dabl, двойная, ko\'p go\'sht',
      ),
      PresetFoodItem(
        title: 'Fitter Shaurma',
        subtitle: 'Dietik tovuq va yangi sabzavot',
        url: 'https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=600&auto=format&fit=crop&q=80',
        keywords: 'fit, fitter, dietik, фитнес, sabzavot',
      ),
      PresetFoodItem(
        title: 'Qazili Shaurma',
        subtitle: 'Milliy qazi bo\'laklari bilan',
        url: 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=600&auto=format&fit=crop&q=80',
        keywords: 'qazi, kazy, казы, milliy, shaurma',
      ),
      PresetFoodItem(
        title: 'Barbekyu Shaurma',
        subtitle: 'Tutuqli BBQ sous bilan',
        url: 'https://images.unsplash.com/photo-1607013251379-e6eecfffe234?w=600&auto=format&fit=crop&q=80',
        keywords: 'barbekyu, bbq, барбекю, sous',
      ),
      PresetFoodItem(
        title: 'Sirli Tandir Shaurma',
        subtitle: 'Erigan pishloq va tandir ta\'mi',
        url: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80',
        keywords: 'sirli, pishloq, cheese, сыр, tandir',
      ),
      PresetFoodItem(
        title: 'Jalapeno Shaurma',
        subtitle: 'Meksikacha achchiq qalampir',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
        keywords: 'jalapeno, xalapeno, халапеньо, chili',
      ),
      PresetFoodItem(
        title: 'Shaurma Roll',
        subtitle: 'Kesilgan bo\'lakli shaurma',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
        keywords: 'roll, ролл, bo\'lakli shaurma',
      ),
      PresetFoodItem(
        title: 'Qarsildoq Shaurma',
        subtitle: 'Qo\'shimcha qarsildoq chipslar',
        url: 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=600&auto=format&fit=crop&q=80',
        keywords: 'qarsildoq, crispy, хрустящая',
      ),
      PresetFoodItem(
        title: 'Mini Tandir Shaurma',
        subtitle: 'Ixcham tandir shaurmasi',
        url: 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600&auto=format&fit=crop&q=80',
        keywords: 'mini tandir, мини тандыр',
      ),
      PresetFoodItem(
        title: 'Pishloqli Doner',
        subtitle: 'Baton nonda erigan mozzarella',
        url: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=600&auto=format&fit=crop&q=80',
        keywords: 'doner, pishloq, сырный донер',
      ),
      PresetFoodItem(
        title: 'Max Shaurma Set',
        subtitle: 'Katta shaurma, fri va sous',
        url: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&auto=format&fit=crop&q=80',
        keywords: 'set, kombo, комбо, shaurma set',
      ),
      PresetFoodItem(
        title: 'Turkiy Shaurma',
        subtitle: 'An\'anaviy turk uslubida',
        url: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80',
        keywords: 'turkish, turkcha, турецкая',
      ),
      PresetFoodItem(
        title: 'Shirador Shaurma',
        subtitle: 'Qo\'shimcha sous va shirador go\'sht',
        url: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&auto=format&fit=crop&q=80',
        keywords: 'shirador, sochniy, сочная',
      ),
      PresetFoodItem(
        title: 'Bolalar Shaurmasi',
        subtitle: 'Yengil va achchiqsiz',
        url: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=600&auto=format&fit=crop&q=80',
        keywords: 'bolalar, kids, детская',
      ),
      PresetFoodItem(
        title: 'Zavero Gigant Shaurma',
        subtitle: '1 metrli maxsus gigant shaurma',
        url: 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=600&auto=format&fit=crop&q=80',
        keywords: 'gigant, mega, гигант, 1 metr',
      ),
    ],
  ),
  PresetFoodCategory(
    title: 'Lavash',
    icon: Icons.bakery_dining_rounded,
    items: [
      PresetFoodItem(
        title: 'Klassik Lavash',
        subtitle: 'Mol go\'shti, pomidor va bodring',
        url: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&auto=format&fit=crop&q=80',
        keywords: 'lavash, лаваш, wrap, klassik',
      ),
      PresetFoodItem(
        title: 'Katta Go\'shtli Lavash',
        subtitle: 'Katta porsiya shirador go\'sht',
        url: 'https://images.unsplash.com/photo-1561651823-34feb02250e4?w=600&auto=format&fit=crop&q=80',
        keywords: 'katta, big, max, мясной лаваш',
      ),
      PresetFoodItem(
        title: 'Tovuqli Lavash',
        subtitle: 'Tovuq filesi va oq sous',
        url: 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=600&auto=format&fit=crop&q=80',
        keywords: 'tovuq, chicken, куриный лаваш',
      ),
      PresetFoodItem(
        title: 'Pishloqli Lavash',
        subtitle: 'Mozzarella va chedder pishloqli',
        url: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80',
        keywords: 'pishloq, cheese, сырный лаваш',
      ),
      PresetFoodItem(
        title: 'Tandir Lavash',
        subtitle: 'Haqiqiy tandirda qizargan',
        url: 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600&auto=format&fit=crop&q=80',
        keywords: 'tandir, тандырный лаваш',
      ),
      PresetFoodItem(
        title: 'Achchiq Lavash',
        subtitle: 'Achchiq qalampir va sous',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
        keywords: 'achchiq, hot, spicy, острый',
      ),
      PresetFoodItem(
        title: 'Mini Lavash',
        subtitle: 'Bolalar va yengil tamaddi',
        url: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=600&auto=format&fit=crop&q=80',
        keywords: 'mini, kichik, мини лаваш',
      ),
      PresetFoodItem(
        title: 'Qazili Lavash',
        subtitle: 'Milliy qazi va mol go\'shti',
        url: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80',
        keywords: 'qazi, казы, лаваш с казы',
      ),
      PresetFoodItem(
        title: 'Fitter Lavash',
        subtitle: 'Kam yog\'li tovuq filesi',
        url: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=600&auto=format&fit=crop&q=80',
        keywords: 'fit, fitter, dietik, фитнес',
      ),
      PresetFoodItem(
        title: 'Lavash Box',
        subtitle: 'Fri kartoshka va sous bilan set',
        url: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
        keywords: 'box, boks, бокс, set',
      ),
      PresetFoodItem(
        title: 'Go\'sht & Pishloq Lavash',
        subtitle: 'Ko\'p go\'sht va erigan pishloq',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        keywords: 'go\'sht, pishloq, мясо сыр',
      ),
      PresetFoodItem(
        title: 'Qo\'ziqorinli Lavash',
        subtitle: 'Qovurilgan shampinyon qo\'ziqorin',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
        keywords: 'qo\'ziqorin, mushroom, грибы',
      ),
      PresetFoodItem(
        title: 'Double Go\'sht Lavash',
        subtitle: '2 barobar ko\'proq go\'sht',
        url: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80',
        keywords: 'double, 2x, двойное мясо',
      ),
      PresetFoodItem(
        title: 'Lavash Porsiya',
        subtitle: 'Likopchada salat va garnir',
        url: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&auto=format&fit=crop&q=80',
        keywords: 'porsiya, порция, tarelka',
      ),
      PresetFoodItem(
        title: 'Zavero Special Lavash',
        subtitle: 'Mualliflik sousi bilan maxsus',
        url: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&auto=format&fit=crop&q=80',
        keywords: 'special, zavero, фирменный',
      ),
      PresetFoodItem(
        title: 'Mol Go\'shtli Tandir',
        subtitle: 'Shirador mol go\'shti tandirda',
        url: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80',
        keywords: 'mol, tandir, говядина',
      ),
      PresetFoodItem(
        title: 'Kichik Tovuq Lavash',
        subtitle: 'Standart o\'lchamdagi tovuqli',
        url: 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=600&auto=format&fit=crop&q=80',
        keywords: 'kichik, tovuq, standart',
      ),
      PresetFoodItem(
        title: 'Lavash Roll',
        subtitle: 'Rulet qilib kesilgan mini bo\'laklar',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
        keywords: 'roll, ролл, bo\'lak',
      ),
      PresetFoodItem(
        title: 'Pishloqli Tandir Lavash',
        subtitle: 'Tandirda qizargan pishloq bomba',
        url: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80',
        keywords: 'pishloqli tandir, сырный тандыр',
      ),
      PresetFoodItem(
        title: 'Assorti Lavash',
        subtitle: 'Mol va tovuq go\'shti birga',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
        keywords: 'assorti, mix, ассорти',
      ),
      PresetFoodItem(
        title: 'Achchiq Tandir Lavash',
        subtitle: 'Tandirda qizargan olovli ta\'m',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
        keywords: 'achchiq tandir, острый тандыр',
      ),
      PresetFoodItem(
        title: 'Meksikancha Lavash',
        subtitle: 'Lobiya, makkajo\'xori va salsa',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
        keywords: 'mexican, meksika, salsa, кукуруза',
      ),
      PresetFoodItem(
        title: 'Barbekyu Lavash',
        subtitle: 'Tutuqli BBQ lazzati',
        url: 'https://images.unsplash.com/photo-1607013251379-e6eecfffe234?w=600&auto=format&fit=crop&q=80',
        keywords: 'barbekyu, bbq, барбекю',
      ),
      PresetFoodItem(
        title: 'Sosiskali Lavash',
        subtitle: 'Dudlangan sosiska va pishloq',
        url: 'https://images.unsplash.com/photo-1619740455993-9e612b1af08a?w=600&auto=format&fit=crop&q=80',
        keywords: 'sosiska, сосиска, sosiskali',
      ),
      PresetFoodItem(
        title: 'Doner Lavash',
        subtitle: 'Yupqa xamirdagi doner kabob',
        url: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=600&auto=format&fit=crop&q=80',
        keywords: 'doner, döner, донер лаваш',
      ),
      PresetFoodItem(
        title: 'Bekonli Lavash',
        subtitle: 'Qovurilgan bekon bo\'laklari bilan',
        url: 'https://images.unsplash.com/photo-1582196016295-f8c8bd4b3e99?w=600&auto=format&fit=crop&q=80',
        keywords: 'bekon, bacon, бекон',
      ),
      PresetFoodItem(
        title: 'Sabzavotli Lavash (Veg)',
        subtitle: 'Faqat yangi sabzavotlar va sous',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
        keywords: 'veg, sabzavot, овощной',
      ),
      PresetFoodItem(
        title: 'Mini Roll Lavash',
        subtitle: '4 bo\'lakli mayda roll',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
        keywords: 'mini roll, мини ролл',
      ),
      PresetFoodItem(
        title: 'Pishloq Bomba Lavash',
        subtitle: '3 xil erigan pishloq bilan',
        url: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80',
        keywords: 'pishloq bomba, сырная бомба',
      ),
      PresetFoodItem(
        title: 'Double Tandir Lavash',
        subtitle: 'Katta porsiya tandir lavash',
        url: 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=600&auto=format&fit=crop&q=80',
        keywords: 'double tandir, двойной тандыр',
      ),
    ],
  ),
  PresetFoodCategory(
    title: 'Burger & Fast Food',
    icon: Icons.fastfood_rounded,
    items: [
      PresetFoodItem(
        title: 'Cheeseburger',
        subtitle: 'Klassik pishloqli kotlet',
        url: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80',
        keywords: 'cheeseburger, chizburger, чизбургер, cheese, burger',
      ),
      PresetFoodItem(
        title: 'Hamburger',
        subtitle: 'Shirador mol go\'shti kotleti',
        url: 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop&q=80',
        keywords: 'hamburger, gamburger, гамбургер, burger',
      ),
      PresetFoodItem(
        title: 'Double Cheeseburger',
        subtitle: '2 ta kotlet va 2 qavat pishloq',
        url: 'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?w=600&auto=format&fit=crop&q=80',
        keywords: 'double, dabl, двойной чизбургер, burger',
      ),
      PresetFoodItem(
        title: 'Big Burger',
        subtitle: 'Katta o\'lchamli maxsus burger',
        url: 'https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=600&auto=format&fit=crop&q=80',
        keywords: 'big, big burger, биг бургер',
      ),
      PresetFoodItem(
        title: 'Chiken Burger',
        subtitle: 'Qarsildoq tovuq filesi',
        url: 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=600&auto=format&fit=crop&q=80',
        keywords: 'chiken, chicken, чикен бургер, tovuq',
      ),
      PresetFoodItem(
        title: 'Barbecue Burger',
        subtitle: 'Tutuqli BBQ sous va pishloq',
        url: 'https://images.unsplash.com/photo-1607013251379-e6eecfffe234?w=600&auto=format&fit=crop&q=80',
        keywords: 'barbecue, bbq, барбекю бургер',
      ),
      PresetFoodItem(
        title: 'Qora Burger (Black)',
        subtitle: 'Qora nonda maxsus shirador kotlet',
        url: 'https://images.unsplash.com/photo-1619881589775-96101c51950e?w=600&auto=format&fit=crop&q=80',
        keywords: 'qora, black, черный бургер',
      ),
      PresetFoodItem(
        title: 'Mini Burger',
        subtitle: 'Bolalar uchun kichik porsiya',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
        keywords: 'mini burger, мини бургер',
      ),
      PresetFoodItem(
        title: 'Zavero Max Burger',
        subtitle: 'Barcha qo\'shimchalar bilan mega burger',
        url: 'https://images.unsplash.com/photo-1547584370-2cc98b8b8dc8?w=600&auto=format&fit=crop&q=80',
        keywords: 'zavero max, mega, фирменный',
      ),
      PresetFoodItem(
        title: 'Jalapeno Burger',
        subtitle: 'Achchiq qalampirli olovli burger',
        url: 'https://images.unsplash.com/photo-1551782450-a2132b4ba21d?w=600&auto=format&fit=crop&q=80',
        keywords: 'jalapeno, острый бургер, chili',
      ),
      PresetFoodItem(
        title: 'Smokey Bacon Burger',
        subtitle: 'Dudlangan bekon va kotlet',
        url: 'https://images.unsplash.com/photo-1582196016295-f8c8bd4b3e99?w=600&auto=format&fit=crop&q=80',
        keywords: 'bacon, bekon, бургер с беконом',
      ),
      PresetFoodItem(
        title: 'Kombo Burger Set',
        subtitle: 'Burger, fri kartoshka va ichimlik',
        url: 'https://images.unsplash.com/photo-1521305916504-4a1121188589?w=600&auto=format&fit=crop&q=80',
        keywords: 'kombo, set, комбо сет',
      ),
      PresetFoodItem(
        title: 'Baliqli Burger (Fish)',
        subtitle: 'Mayin baliq filesi va tartar sous',
        url: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80',
        keywords: 'fish, baliq, рыбный бургер',
      ),
      PresetFoodItem(
        title: 'Qo\'ziqorinli Burger',
        subtitle: 'Qovurilgan shampinyon va pishloq',
        url: 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop&q=80',
        keywords: 'qo\'ziqorin, mushroom, грибной',
      ),
      PresetFoodItem(
        title: 'Double Chiken Burger',
        subtitle: '2 ta qarsildoq tovuq filesi',
        url: 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=600&auto=format&fit=crop&q=80',
        keywords: 'double chicken, двойной чикен',
      ),
      PresetFoodItem(
        title: 'Tuxumli Burger (Egg)',
        subtitle: 'Qovurilgan tuxum va go\'sht',
        url: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80',
        keywords: 'egg, tuxum, бургер с яйцом',
      ),
      PresetFoodItem(
        title: 'Tandir Burger',
        subtitle: 'Tandir nonida burger kotleti',
        url: 'https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=600&auto=format&fit=crop&q=80',
        keywords: 'tandir burger, тандыр',
      ),
      PresetFoodItem(
        title: 'Mini Sliders (3 dona)',
        subtitle: '3 xil ta\'mli mini burgerlar',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
        keywords: 'sliders, slayder, слайдеры',
      ),
      PresetFoodItem(
        title: 'Max Pishloqli Burger',
        subtitle: 'Qo\'shimcha erigan cheddar',
        url: 'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?w=600&auto=format&fit=crop&q=80',
        keywords: 'cheddar, pishloqli, много сыра',
      ),
      PresetFoodItem(
        title: 'Chili Burger',
        subtitle: 'Achchiq chili fasoli sousi bilan',
        url: 'https://images.unsplash.com/photo-1551782450-a2132b4ba21d?w=600&auto=format&fit=crop&q=80',
        keywords: 'chili, chili burger, чили',
      ),
      PresetFoodItem(
        title: 'Fri Kartoshkasi',
        subtitle: 'Qarsildoq oltin fri',
        url: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=600&auto=format&fit=crop&q=80',
        keywords: 'fri, french fries, картофель фри',
      ),
      PresetFoodItem(
        title: 'Qishloqcha Fri',
        subtitle: 'Po-derevenski kartoshka bo\'laklari',
        url: 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?w=600&auto=format&fit=crop&q=80',
        keywords: 'derevenski, qishloqcha, по-деревенски',
      ),
      PresetFoodItem(
        title: 'Pishloqli Fri',
        subtitle: 'Erigan pishloq sousi bilan fri',
        url: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=600&auto=format&fit=crop&q=80',
        keywords: 'cheese fries, pishloqli fri',
      ),
      PresetFoodItem(
        title: 'Nagets (6 dona)',
        subtitle: 'Tovuqli oltin nagetslar',
        url: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80',
        keywords: 'nagets, nuggets, наггетсы',
      ),
      PresetFoodItem(
        title: 'Nagets (9 dona)',
        subtitle: 'Katta porsiya tovuq nagets',
        url: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80',
        keywords: 'nagets 9, nuggets 9',
      ),
      PresetFoodItem(
        title: 'Tovuq Stripsilari',
        subtitle: 'Qarsildoq tovuq filesi bo\'laklari',
        url: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80',
        keywords: 'strips, стрипсы, tovuq strips',
      ),
      PresetFoodItem(
        title: 'Qarsildoq Qanotchalar',
        subtitle: 'Achchiq-shirin qanotlar',
        url: 'https://images.unsplash.com/photo-1527477321005-4d01d75bc660?w=600&auto=format&fit=crop&q=80',
        keywords: 'wings, qanotcha, крылышки',
      ),
      PresetFoodItem(
        title: 'Pishloqli Halqalar',
        subtitle: 'Mozzarella pishloqli halqalar',
        url: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600&auto=format&fit=crop&q=80',
        keywords: 'cheese rings, сырные кольца',
      ),
      PresetFoodItem(
        title: 'Piyozli Halqalar',
        subtitle: 'Qarsildoq klyarda piyoz halqalari',
        url: 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?w=600&auto=format&fit=crop&q=80',
        keywords: 'onion rings, луковые кольца',
      ),
      PresetFoodItem(
        title: 'Tovuqli Popkorn',
        subtitle: 'Mayda qarsildoq tovuq donalari',
        url: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80',
        keywords: 'popcorn chicken, попкорн куриный',
      ),
    ],
  ),
  PresetFoodCategory(
    title: 'Hot-dog & Sendvich',
    icon: Icons.breakfast_dining_rounded,
    items: [
      PresetFoodItem(
        title: 'Klassik Hot-dog',
        subtitle: 'Sosiska, xantal va sous',
        url: 'https://images.unsplash.com/photo-1619740455993-9e612b1af08a?w=600&auto=format&fit=crop&q=80',
        keywords: 'hotdog, hot-dog, хот-дог, sosiska',
      ),
      PresetFoodItem(
        title: 'Katta Hot-dog (Max)',
        subtitle: 'Katta dudlangan sosiska',
        url: 'https://images.unsplash.com/photo-1627059173003-8898198947f6?w=600&auto=format&fit=crop&q=80',
        keywords: 'katta hotdog, big hot-dog',
      ),
      PresetFoodItem(
        title: 'Ovchi Hot-dog (Hunter)',
        subtitle: 'Ovchi sosiskasi bilan xushbo\'y',
        url: 'https://images.unsplash.com/photo-1612528443702-f6741f74a04b?w=600&auto=format&fit=crop&q=80',
        keywords: 'hunter, ovchi, охотничий хот-дог',
      ),
      PresetFoodItem(
        title: 'Pishloqli Hot-dog',
        subtitle: 'Erigan mozzarella va chedder',
        url: 'https://images.unsplash.com/photo-1541214113241-21578d2d9b62?w=600&auto=format&fit=crop&q=80',
        keywords: 'cheese, pishloq, сырный хот-дог',
      ),
      PresetFoodItem(
        title: 'Achchiq Jalapeno Hot-dog',
        subtitle: 'Olovli achchiq qalampir va sous',
        url: 'https://images.unsplash.com/photo-1585238342024-78d387f4a707?w=600&auto=format&fit=crop&q=80',
        keywords: 'jalapeno, острый, spicy hot-dog',
      ),
      PresetFoodItem(
        title: 'Frantsuzcha Hot-dog',
        subtitle: 'Baqat nonda sosiskali',
        url: 'https://images.unsplash.com/photo-1592415486689-125cbbfcbee2?w=600&auto=format&fit=crop&q=80',
        keywords: 'french, fransuzcha, французский хот-дог',
      ),
      PresetFoodItem(
        title: 'Daniya Hot-dogi',
        subtitle: 'Qovurilgan piyoz va shirin bodring',
        url: 'https://images.unsplash.com/photo-1619740455993-9e612b1af08a?w=600&auto=format&fit=crop&q=80',
        keywords: 'danish, датский хот-дог',
      ),
      PresetFoodItem(
        title: 'Klabb Sendvich',
        subtitle: 'Uch burchakli toster non tovuq bilan',
        url: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80',
        keywords: 'club sandwich, klabb sendvich, клаб сэндвич',
      ),
      PresetFoodItem(
        title: 'Toster Sendvich',
        subtitle: 'Pishloq va vetchina tosterda',
        url: 'https://images.unsplash.com/photo-1554433607-66b5efe9d304?w=600&auto=format&fit=crop&q=80',
        keywords: 'toster, toast, тост сэндвич',
      ),
      PresetFoodItem(
        title: 'Tovuqli Sendvich',
        subtitle: 'Gril tovuq filesi va ko\'katlar',
        url: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80',
        keywords: 'chicken sandwich, сэндвич с курицей',
      ),
      PresetFoodItem(
        title: 'Mol Go\'shtli Baget Sendvich',
        subtitle: 'Qarsildoq baget nonda go\'sht',
        url: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=600&auto=format&fit=crop&q=80',
        keywords: 'baget, baguette, сэндвич в багете',
      ),
      PresetFoodItem(
        title: 'Tunetsli Sendvich',
        subtitle: 'Dengiz tunets balig\'i va tuxum',
        url: 'https://images.unsplash.com/photo-1521390188846-e2a39b7ef4a8?w=600&auto=format&fit=crop&q=80',
        keywords: 'tuna, tunets, тунец сэндвич',
      ),
      PresetFoodItem(
        title: 'Pishloqli Panini',
        subtitle: 'Grilda pishirilgan italyancha panini',
        url: 'https://images.unsplash.com/photo-1539252554453-80ab65ce3586?w=600&auto=format&fit=crop&q=80',
        keywords: 'panini, панини, cheese panini',
      ),
      PresetFoodItem(
        title: 'Ham & Cheese Sendvich',
        subtitle: 'Klassik pishloq va vetchina',
        url: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=600&auto=format&fit=crop&q=80',
        keywords: 'ham and cheese, ветчина и сыр',
      ),
      PresetFoodItem(
        title: 'Gril Sendvich',
        subtitle: 'Tosterda qizargan qarsildoq non',
        url: 'https://images.unsplash.com/photo-1567234669003-dce7a7a88821?w=600&auto=format&fit=crop&q=80',
        keywords: 'grilled, гриль сэндвич',
      ),
      PresetFoodItem(
        title: 'Mini Sendvichlar Assorti',
        subtitle: 'Bir nechta ta\'mlar to\'plami',
        url: 'https://images.unsplash.com/photo-1481070414801-51fd732d7184?w=600&auto=format&fit=crop&q=80',
        keywords: 'mini sandwich, мини сэндвичи',
      ),
      PresetFoodItem(
        title: 'Max Sousli Hot-dog',
        subtitle: 'Ko\'p sousli va xushbo\'y piyozli',
        url: 'https://images.unsplash.com/photo-1585238341267-1cfbc2046a55?w=600&auto=format&fit=crop&q=80',
        keywords: 'sous, hot-dog',
      ),
      PresetFoodItem(
        title: 'Double Sosiska Hot-dog',
        subtitle: '2 ta dudlangan sosiska bilan',
        url: 'https://images.unsplash.com/photo-1627059173003-8898198947f6?w=600&auto=format&fit=crop&q=80',
        keywords: 'double, 2 sosiska, двойной хот-дог',
      ),
      PresetFoodItem(
        title: 'Tovuqli Panini',
        subtitle: 'Tovuq va pishloqli qarsildoq panini',
        url: 'https://images.unsplash.com/photo-1539252554453-80ab65ce3586?w=600&auto=format&fit=crop&q=80',
        keywords: 'chicken panini, панини с курицей',
      ),
      PresetFoodItem(
        title: 'Qazili Sendvich',
        subtitle: 'Milliy qazi va sariyog\' bilan',
        url: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80',
        keywords: 'qazi, сэндвич с казы',
      ),
      PresetFoodItem(
        title: 'Kruassan Sendvich',
        subtitle: 'Mayin kruassanda vetchina va pishloq',
        url: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=600&auto=format&fit=crop&q=80',
        keywords: 'croissant, kruassan, круассан сэндвич',
      ),
      PresetFoodItem(
        title: 'Lososli Sendvich',
        subtitle: 'Qizil baliq va qaymoqli krem-chiz',
        url: 'https://images.unsplash.com/photo-1521390188846-e2a39b7ef4a8?w=600&auto=format&fit=crop&q=80',
        keywords: 'salmon, losos, сэндвич с семгой',
      ),
      PresetFoodItem(
        title: 'Sendvich Roll',
        subtitle: 'Yupqa xamirdagi sendvich ruleti',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
        keywords: 'roll sandwich, сэндвич ролл',
      ),
      PresetFoodItem(
        title: 'Katta Klabb Set',
        subtitle: 'Klabb sendvich va fri kartoshka',
        url: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80',
        keywords: 'club set, клаб сет',
      ),
      PresetFoodItem(
        title: 'Bekonli Sendvich',
        subtitle: 'Qovurilgan bekon va pomidor',
        url: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=600&auto=format&fit=crop&q=80',
        keywords: 'bacon sandwich, сэндвич с беконом',
      ),
    ],
  ),
  PresetFoodCategory(
    title: 'Pitsa & Piroglar',
    icon: Icons.local_pizza_rounded,
    items: [
      PresetFoodItem(
        title: 'Margarita Pitsa',
        subtitle: 'Pomidor va erigan mozzarella',
        url: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&auto=format&fit=crop&q=80',
        keywords: 'pizza, margarita, пицца маргарита, mozzarella',
      ),
      PresetFoodItem(
        title: 'Pepperoni Pitsa',
        subtitle: 'Dudlangan achchiq kolbasa bilan',
        url: 'https://images.unsplash.com/photo-1628840042765-356cda07504e?w=600&auto=format&fit=crop&q=80',
        keywords: 'pepperoni, пепперони, pizza',
      ),
      PresetFoodItem(
        title: '4 Pishloqli Pitsa',
        subtitle: 'To\'rt xil nozik pishloq uyg\'unligi',
        url: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80',
        keywords: '4 сыра, four cheese, 4 pishloq',
      ),
      PresetFoodItem(
        title: 'Qo\'ziqorinli Pitsa',
        subtitle: 'Shampinyon va nozik oq sous',
        url: 'https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=600&auto=format&fit=crop&q=80',
        keywords: 'mushroom, грибная пицца, qo\'ziqorin',
      ),
      PresetFoodItem(
        title: 'Go\'shtli Pitsa (Meat)',
        subtitle: 'Mol go\'shti, kolbasa va qazi',
        url: 'https://images.unsplash.com/photo-1594007654729-407eedc4be65?w=600&auto=format&fit=crop&q=80',
        keywords: 'meat, go\'shtli, мясная пицца',
      ),
      PresetFoodItem(
        title: 'Zavero Assorti Pitsa',
        subtitle: 'Barcha masalliqlar jamlanmasi',
        url: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&auto=format&fit=crop&q=80',
        keywords: 'assorti, zavero, фирменная пицца',
      ),
      PresetFoodItem(
        title: 'Tovuqli Pitsa (Chicken)',
        subtitle: 'Tovuq go\'shti, zaytun va makkajo\'xori',
        url: 'https://images.unsplash.com/photo-1534308983496-4fabb1a015ee?w=600&auto=format&fit=crop&q=80',
        keywords: 'chicken, tovuq, куриная пицца',
      ),
      PresetFoodItem(
        title: 'Barbekyu Pitsa (BBQ)',
        subtitle: 'Tutuqli BBQ sous va qovurilgan tovuq',
        url: 'https://images.unsplash.com/photo-1604382355076-af4b0eb60143?w=600&auto=format&fit=crop&q=80',
        keywords: 'bbq, barbekyu, пицца барбекю',
      ),
      PresetFoodItem(
        title: 'Dengiz Mahsulotli Pitsa',
        subtitle: 'Krevyetka, kalmar va qizil sous',
        url: 'https://images.unsplash.com/photo-1571407970349-bc81e7e96d47?w=600&auto=format&fit=crop&q=80',
        keywords: 'seafood, dengiz, пицца с морепродуктами',
      ),
      PresetFoodItem(
        title: 'Achchiq Diavola',
        subtitle: 'Achchiq qalampir va go\'sht',
        url: 'https://images.unsplash.com/photo-1588315029754-2dd089d39a1a?w=600&auto=format&fit=crop&q=80',
        keywords: 'diavola, spicy, острая диавола',
      ),
      PresetFoodItem(
        title: 'Gavaya Pitsasi',
        subtitle: 'Ananas bo\'laklari va tovuq',
        url: 'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=600&auto=format&fit=crop&q=80',
        keywords: 'hawaiian, ananas, гавайская пицца',
      ),
      PresetFoodItem(
        title: 'Kalzone (Yopiq pitsa)',
        subtitle: 'Shirador yopiq pitsa',
        url: 'https://images.unsplash.com/photo-1541745537411-b8046dc6d66c?w=600&auto=format&fit=crop&q=80',
        keywords: 'calzone, kalzone, кальцоне',
      ),
      PresetFoodItem(
        title: 'Pishloqli Xachapuri',
        subtitle: 'Gruzincha qayiqcha va pishloq',
        url: 'https://images.unsplash.com/photo-1608897013039-887f21d8c804?w=600&auto=format&fit=crop&q=80',
        keywords: 'xachapuri, хачапури, ajarskiy',
      ),
      PresetFoodItem(
        title: 'Menrel Xachapurisi',
        subtitle: 'Ustiga ko\'p pishloq sepilgan xachapuri',
        url: 'https://images.unsplash.com/photo-1608897013039-887f21d8c804?w=600&auto=format&fit=crop&q=80',
        keywords: 'menrel, хачапури по-мегрельски',
      ),
      PresetFoodItem(
        title: 'Go\'shtli Pirog',
        subtitle: 'Qatlama xamirdan shirador pirog',
        url: 'https://images.unsplash.com/photo-1608039829572-78524f79c4c7?w=600&auto=format&fit=crop&q=80',
        keywords: 'pirog, мясной пирог, go\'shtli',
      ),
      PresetFoodItem(
        title: 'Go\'shtli Lahmajun',
        subtitle: 'Yupqa turkcha xamir va qiyma',
        url: 'https://images.unsplash.com/photo-1626074353765-517a681e40be?w=600&auto=format&fit=crop&q=80',
        keywords: 'lahmacun, lahmajun, лахмаджун',
      ),
      PresetFoodItem(
        title: 'Pide Go\'shtli',
        subtitle: 'Qayiqcha shaklidagi turk pidesi',
        url: 'https://images.unsplash.com/photo-1579751626657-72bc17010498?w=600&auto=format&fit=crop&q=80',
        keywords: 'pide, пиде с мясом',
      ),
      PresetFoodItem(
        title: 'Pide Pishloqli',
        subtitle: 'Eritilgan pishloqli turk pidesi',
        url: 'https://images.unsplash.com/photo-1579751626657-72bc17010498?w=600&auto=format&fit=crop&q=80',
        keywords: 'pide сырный, pishloqli pide',
      ),
      PresetFoodItem(
        title: 'Mini Pitsachalar',
        subtitle: 'Bolalar uchun ixcham pitsalar',
        url: 'https://images.unsplash.com/photo-1595854341625-f33ee10dbf94?w=600&auto=format&fit=crop&q=80',
        keywords: 'mini pizza, мини пиццы',
      ),
      PresetFoodItem(
        title: 'Zavero Mega Pitsa 40cm',
        subtitle: 'Katta oilaviy pitsa 40sm',
        url: 'https://images.unsplash.com/photo-1590947132387-155cc02f3212?w=600&auto=format&fit=crop&q=80',
        keywords: 'mega, 40cm, большая пицца',
      ),
      PresetFoodItem(
        title: 'Pomidor-Bazilik Pitsa',
        subtitle: 'Yangi pomidor, rayhon va pishloq',
        url: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&auto=format&fit=crop&q=80',
        keywords: 'bazilik, rayhon, томаты базилик',
      ),
      PresetFoodItem(
        title: 'Qo\'ziqorin & Tovuq Pitsa',
        subtitle: 'Shampinyon, tovuq va oq qayla',
        url: 'https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=600&auto=format&fit=crop&q=80',
        keywords: 'chicken mushroom, курица грибы',
      ),
      PresetFoodItem(
        title: 'Qazili Milliy Pitsa',
        subtitle: 'Qazi bo\'laklari bilan o\'zbekona pitsa',
        url: 'https://images.unsplash.com/photo-1594007654729-407eedc4be65?w=600&auto=format&fit=crop&q=80',
        keywords: 'qazi pizza, пицца с казы',
      ),
      PresetFoodItem(
        title: 'Oq sousli Pitsa',
        subtitle: 'Qaymoqli oq sous va mozzarella',
        url: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80',
        keywords: 'white pizza, белая пицца',
      ),
      PresetFoodItem(
        title: 'Tovuq va Ananas Pitsa',
        subtitle: 'Shirin ananas va dudlangan tovuq',
        url: 'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=600&auto=format&fit=crop&q=80',
        keywords: 'ananas tovuq, ананас курица',
      ),
    ],
  ),
  PresetFoodCategory(
    title: 'Milliy taomlar',
    icon: Icons.outdoor_grill_rounded,
    items: [
      PresetFoodItem(
        title: 'Choyxona Oshi',
        subtitle: 'Dumba va noxatli an\'anaviy palov',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
        keywords: 'osh, palov, плов, чайханский плов, rice',
      ),
      PresetFoodItem(
        title: 'To\'y Oshi (Devzira)',
        subtitle: 'Qazi, bedana tuxum va mayizli osh',
        url: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&auto=format&fit=crop&q=80',
        keywords: 'devzira, to\'y oshi, свадебный плов, девзира',
      ),
      PresetFoodItem(
        title: 'Samarqand Oshi',
        subtitle: 'Sariq sabzili Samarqandcha osh',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
        keywords: 'samarqand, самаркандский плов',
      ),
      PresetFoodItem(
        title: 'Toshkent Oshi',
        subtitle: 'Klassik Toshkent to\'y oshi',
        url: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&auto=format&fit=crop&q=80',
        keywords: 'toshkent, ташкентский плов',
      ),
      PresetFoodItem(
        title: 'Qazi-Karta Osh',
        subtitle: 'Sergo\'sht qazi va karta bilan',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
        keywords: 'qazi, karta, плов с казы',
      ),
      PresetFoodItem(
        title: 'Tandir Somsa',
        subtitle: 'Qarsildoq xamir va shirador go\'sht',
        url: 'https://images.unsplash.com/photo-1608039829572-78524f79c4c7?w=600&auto=format&fit=crop&q=80',
        keywords: 'somsa, samsa, самса, тандырная самса',
      ),
      PresetFoodItem(
        title: 'Qatlama Go\'shtli Somsa',
        subtitle: 'Qavat-qavat mayin xamirdan somsa',
        url: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&auto=format&fit=crop&q=80',
        keywords: 'qatlama, слоеная самса',
      ),
      PresetFoodItem(
        title: 'Qovoqli Somsa',
        subtitle: 'Shirin va sershira qovoqli somsa',
        url: 'https://images.unsplash.com/photo-1608039829572-78524f79c4c7?w=600&auto=format&fit=crop&q=80',
        keywords: 'qovoq, самса с тыквой',
      ),
      PresetFoodItem(
        title: 'Ko\'k Somsa',
        subtitle: 'Bahoriy xushbo\'y ko\'katli somsa',
        url: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&auto=format&fit=crop&q=80',
        keywords: 'ko\'k, самса с зеленью',
      ),
      PresetFoodItem(
        title: 'Kartoshkali Somsa',
        subtitle: 'Xushbo\'y ziravorli kartoshka',
        url: 'https://images.unsplash.com/photo-1608039829572-78524f79c4c7?w=600&auto=format&fit=crop&q=80',
        keywords: 'kartoshka, самса с картошкой',
      ),
      PresetFoodItem(
        title: 'Shashlik Qiyma',
        subtitle: 'Mayin qiyma go\'sht kabob',
        url: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
        keywords: 'shashlik, kabob, шашлык молотый, люля кебаб',
      ),
      PresetFoodItem(
        title: 'Shashlik Kuskovoy',
        subtitle: 'Mol va qo\'y go\'shti lo\'la',
        url: 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=600&auto=format&fit=crop&q=80',
        keywords: 'kuskovoy, кусковой шашлык, kabob',
      ),
      PresetFoodItem(
        title: 'Jigar Shashlik',
        subtitle: 'Dumba yog\'i bilan o\'ralgan jigar',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        keywords: 'jigar, печень, шашлык из печени',
      ),
      PresetFoodItem(
        title: 'Tovuq Shashlik',
        subtitle: 'Shirador file va qanotlar',
        url: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=600&auto=format&fit=crop&q=80',
        keywords: 'tovuq shashlik, куриный шашлык',
      ),
      PresetFoodItem(
        title: 'Napoleon Shashlik',
        subtitle: 'Yupqa go\'sht va dumba qatlamlari',
        url: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
        keywords: 'napoleon, наполеон шашлык',
      ),
      PresetFoodItem(
        title: 'Qanot Shashlik',
        subtitle: 'Qovurilgan xushbo\'y tovuq qanotlari',
        url: 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=600&auto=format&fit=crop&q=80',
        keywords: 'qanot, крылья шашлык',
      ),
      PresetFoodItem(
        title: 'Qozon Kabob',
        subtitle: 'Qovurilgan qarsildoq go\'sht va kartoshka',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
        keywords: 'qozon kabob, казан кебаб',
      ),
      PresetFoodItem(
        title: 'Cho\'zma Lag\'mon (Sho\'rva)',
        subtitle: 'Qo\'lda cho\'zilgan xamir va boy qayla',
        url: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80',
        keywords: 'lag\'mon, lagman, лагман суп',
      ),
      PresetFoodItem(
        title: 'Qovurma Lag\'mon',
        subtitle: 'Sabzavot va go\'sht bilan qovurilgan',
        url: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80',
        keywords: 'qovurma lag\'mon, жареный лагман',
      ),
      PresetFoodItem(
        title: 'Uyg\'ur Lag\'mon',
        subtitle: 'Qalin qaylali an\'anaviy Uyg\'ur lag\'mon',
        url: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80',
        keywords: 'uygur lagman, уйгурский лагман',
      ),
      PresetFoodItem(
        title: 'Go\'shtli Manti',
        subtitle: 'Shirador mayin go\'shtli bug\'da manti',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
        keywords: 'manti, манты с мясом, dumplings',
      ),
      PresetFoodItem(
        title: 'Qovoqli Manti',
        subtitle: 'Qovoq va dumba yog\'li manti',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
        keywords: 'qovoqli manti, манты с тыквой',
      ),
      PresetFoodItem(
        title: 'Mastava',
        subtitle: 'Guruch va qatiqli xushbo\'y sho\'rva',
        url: 'https://images.unsplash.com/photo-1547592180-85f173990554?w=600&auto=format&fit=crop&q=80',
        keywords: 'mastava, мастава, soup',
      ),
      PresetFoodItem(
        title: 'Sho\'rva (Qo\'y go\'shtli)',
        subtitle: 'Sergo\'sht qovurilmagan qaynatma sho\'rva',
        url: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80',
        keywords: 'sho\'rva, шурпа, soup, shorva',
      ),
      PresetFoodItem(
        title: 'Ko\'za Sho\'rva',
        subtitle: 'Maxsus sopol idishda pishgan sho\'rva',
        url: 'https://images.unsplash.com/photo-1547592180-85f173990554?w=600&auto=format&fit=crop&q=80',
        keywords: 'ko\'za sho\'rva, суп в горшочке',
      ),
      PresetFoodItem(
        title: 'Chuchvara Sho\'rvada',
        subtitle: 'Qo\'lda tugilgan nozik chuchvara',
        url: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&auto=format&fit=crop&q=80',
        keywords: 'chuchvara, чучвара, пельмени',
      ),
      PresetFoodItem(
        title: 'Qovurma Chuchvara',
        subtitle: 'Qarsildoq qovurilgan mayda chuchvara',
        url: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&auto=format&fit=crop&q=80',
        keywords: 'qovurma chuchvara, жареные пельмени',
      ),
      PresetFoodItem(
        title: 'Norin',
        subtitle: 'Yupqa kesilgan xamir va ot go\'shti',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        keywords: 'norin, нарын, horse meat',
      ),
      PresetFoodItem(
        title: 'Dimlama',
        subtitle: 'Bug\'da pishgan shirador sabzavot va go\'sht',
        url: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
        keywords: 'dimlama, дымляма',
      ),
      PresetFoodItem(
        title: 'Jiz-biz',
        subtitle: 'Qovurilgan shirador dumba va go\'sht',
        url: 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=600&auto=format&fit=crop&q=80',
        keywords: 'jiz-biz, джиз-быз',
      ),
      PresetFoodItem(
        title: 'Tandir Go\'sht',
        subtitle: 'Archa shoxlarida tandirda pishgan go\'sht',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        keywords: 'tandir go\'sht, тандыр гюшт',
      ),
      PresetFoodItem(
        title: 'Do\'lma',
        subtitle: 'Uzum bargiga o\'ralgan shirador go\'sht',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
        keywords: 'do\'lma, долма, dolma',
      ),
      PresetFoodItem(
        title: 'Xonim',
        subtitle: 'Bug\'da pishgan xamir va kartoshka/go\'sht',
        url: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=600&auto=format&fit=crop&q=80',
        keywords: 'xonim, ханум, hanum',
      ),
      PresetFoodItem(
        title: 'Beshbarmoq',
        subtitle: 'Yupqa xamir va ot/mol go\'shti qaylasi',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        keywords: 'beshbarmoq, бешбармак',
      ),
      PresetFoodItem(
        title: 'Qazi Likopchada',
        subtitle: 'Qalampir va piyoz bilan kesilgan qazi',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        keywords: 'qazi, казы, нарезка',
      ),
      PresetFoodItem(
        title: 'Milliy Assorti Go\'sht',
        subtitle: 'Qazi, til va rulet go\'shtlar jamlanmasi',
        url: 'https://images.unsplash.com/photo-1603360946369-dc9bb6258143?w=600&auto=format&fit=crop&q=80',
        keywords: 'assorti go\'sht, мясное ассорти',
      ),
      PresetFoodItem(
        title: 'Qovurilgan Baliq',
        subtitle: 'Oltin tusda qarsildoq qovurilgan baliq',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        keywords: 'baliq, fish, жареная рыба',
      ),
    ],
  ),
  PresetFoodCategory(
    title: 'Salatlar & Gazaklar',
    icon: Icons.set_meal_rounded,
    items: [
      PresetFoodItem(
        title: 'Achchiq-chuchuk',
        subtitle: 'Oshbop ingichka pomidor va piyoz',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
        keywords: 'achchiq-chuchuk, ачик-чучук, шакароб, salad',
      ),
      PresetFoodItem(
        title: 'Sezar Salati (Tovuqli)',
        subtitle: 'Gril tovuq, kruton va parmezan',
        url: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80',
        keywords: 'sezar, caesar, цезарь с курицей',
      ),
      PresetFoodItem(
        title: 'Sezar Salati (Krevetkali)',
        subtitle: 'Qovurilgan krevetka va sezar sous',
        url: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80',
        keywords: 'caesar shrimp, цезарь с креветками',
      ),
      PresetFoodItem(
        title: 'Yunoncha Salat (Greek)',
        subtitle: 'Feta pishloq, zaytun va bodring',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
        keywords: 'greek, yunoncha, греческий салат',
      ),
      PresetFoodItem(
        title: 'Olivye Salati (Go\'shtli)',
        subtitle: 'Klassik go\'shtli bayramona salat',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
        keywords: 'olivye, оливье, russian salad',
      ),
      PresetFoodItem(
        title: 'Mujskoy Kapriz',
        subtitle: 'Qazi, til va pishloqli to\'yimli salat',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        keywords: 'mujskoy kapriz, мужской каприз',
      ),
      PresetFoodItem(
        title: 'Bahor Salati',
        subtitle: 'Rediska, yangi bodring va ko\'katlar',
        url: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80',
        keywords: 'bahor, весенний салат, rediska',
      ),
      PresetFoodItem(
        title: 'Suzma Ko\'katlar Bilan',
        subtitle: 'Xushbo\'y sarimsoqli milliy suzma',
        url: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=600&auto=format&fit=crop&q=80',
        keywords: 'suzma, сузьма с зеленью',
      ),
      PresetFoodItem(
        title: 'Yangi Bodring-Pomidor',
        subtitle: 'Ko\'katlar va o\'simlik yog\'i bilan',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
        keywords: 'bodring pomidor, свежие огурцы помидоры',
      ),
      PresetFoodItem(
        title: 'Sabzavotli Assorti',
        subtitle: 'Yangi pomidor, bodring, bulg\'ori',
        url: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80',
        keywords: 'sabzavot, овощное ассорти',
      ),
      PresetFoodItem(
        title: 'Pishloqli Assorti',
        subtitle: 'Elita pishloqlar va asal/yong\'oq',
        url: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80',
        keywords: 'cheese plate, сырная тарелка, pishloq',
      ),
      PresetFoodItem(
        title: 'Fransuzcha Go\'shtli Salat',
        subtitle: 'Qovurilgan shirador go\'sht va sabzi',
        url: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80',
        keywords: 'fransuzcha, французский салат',
      ),
      PresetFoodItem(
        title: 'Qovurilgan Baqlajon Salati',
        subtitle: 'Qarsildoq baqlajon va shirin sous',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
        keywords: 'baqlajon, хрустящие баклажаны',
      ),
      PresetFoodItem(
        title: 'Smak Salati',
        subtitle: 'Pomidor, qarsildoq suxarik va pishloq',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
        keywords: 'smak, салат смак',
      ),
      PresetFoodItem(
        title: 'Vitamin Salati',
        subtitle: 'Karam, sabzi va ko\'katlar mayonezsiz',
        url: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80',
        keywords: 'vitamin, салат витаминный',
      ),
      PresetFoodItem(
        title: 'Mimoza Salati',
        subtitle: 'Baliq, tuxum va mayin pishloq qatlami',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
        keywords: 'mimoza, салат мимоза',
      ),
      PresetFoodItem(
        title: 'Qisqichbaqasimon Salat (Krab)',
        subtitle: 'Krab tayoqchalari va makkajo\'xori',
        url: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80',
        keywords: 'krab, крабовый салат',
      ),
      PresetFoodItem(
        title: 'Koreyscha Sabzi Salati',
        subtitle: 'Ziravorli achchiq morkovcha',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
        keywords: 'morkovcha, морковча, корейская морковь',
      ),
      PresetFoodItem(
        title: 'Funchoza Salati',
        subtitle: 'Shaffof lapsha va yangi sabzavotlar',
        url: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80',
        keywords: 'funchoza, фунчоза салат',
      ),
      PresetFoodItem(
        title: 'Tuzlamalar Assorti',
        subtitle: 'Tuzlangan pomidor, bodring va sarimsoq',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
        keywords: 'tuzlama, соленья ассорти',
      ),
      PresetFoodItem(
        title: 'Zaytun Assorti',
        subtitle: 'Qora va yashil zaytun mevalari',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
        keywords: 'zaytun, оливки, маслины',
      ),
      PresetFoodItem(
        title: 'Yangi Ko\'katlar Likopchada',
        subtitle: 'Kashnich, ukrop, rayhon va yashil piyoz',
        url: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80',
        keywords: 'ko\'kat, свежая зелень',
      ),
    ],
  ),
  PresetFoodCategory(
    title: 'Garnirlar va fri',
    icon: Icons.kitchen_rounded,
    items: [
      PresetFoodItem(
        title: 'Oltin Fri Kartoshkasi',
        subtitle: 'Klassik qarsildoq qovurilgan fri',
        url: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=600&auto=format&fit=crop&q=80',
        keywords: 'fri, fries, фри, kartoshka',
      ),
      PresetFoodItem(
        title: 'Katta Fri Kartoshkasi',
        subtitle: 'Katta porsiya qarsildoq fri',
        url: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=600&auto=format&fit=crop&q=80',
        keywords: 'big fries, большая фри',
      ),
      PresetFoodItem(
        title: 'Qishloqcha Fri',
        subtitle: 'Po-derevenski ziravorli kartoshka',
        url: 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?w=600&auto=format&fit=crop&q=80',
        keywords: 'derevenski, по-деревенски',
      ),
      PresetFoodItem(
        title: 'Pishloq Sousli Fri',
        subtitle: 'Issiq chedder sousi bilan qoplangan',
        url: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=600&auto=format&fit=crop&q=80',
        keywords: 'cheese fries, фри с сыром',
      ),
      PresetFoodItem(
        title: 'Bekon va Pishloqli Fri',
        subtitle: 'Qovurilgan bekon va erigan pishloq',
        url: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=600&auto=format&fit=crop&q=80',
        keywords: 'bacon fries, фри с беконом',
      ),
      PresetFoodItem(
        title: 'Kartoshka Pyuresi',
        subtitle: 'Sariyog\' va sut bilan mayin pyure',
        url: 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?w=600&auto=format&fit=crop&q=80',
        keywords: 'pyure, mashed potatoes, пюре',
      ),
      PresetFoodItem(
        title: 'Guruch Garnir',
        subtitle: 'Sariyog\'da pishgan oq donador guruch',
        url: 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&auto=format&fit=crop&q=80',
        keywords: 'rice, guruch, рис гарнир',
      ),
      PresetFoodItem(
        title: 'Grechka Garnir',
        subtitle: 'Xushbo\'y sariyog\'li grechka',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
        keywords: 'grechka, buckwheat, гречка',
      ),
      PresetFoodItem(
        title: 'Qovurilgan Sabzavotlar Gril',
        subtitle: 'Bulg\'ori, baqlajon va kabachki',
        url: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80',
        keywords: 'grill vegetables, овощи гриль',
      ),
      PresetFoodItem(
        title: 'Makkajo\'xori Grilda',
        subtitle: 'Sariyog\'li qovurilgan so\'ta',
        url: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80',
        keywords: 'corn, makkajo\'xori, кукуруза',
      ),
      PresetFoodItem(
        title: 'Nagets (6 dona)',
        subtitle: 'Tovuqli oltin rang nagets',
        url: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80',
        keywords: 'nagets 6, наггетсы 6',
      ),
      PresetFoodItem(
        title: 'Nagets (9 dona)',
        subtitle: 'Katta to\'plam tovuq nagetsi',
        url: 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80',
        keywords: 'nagets 9, наггетсы 9',
      ),
      PresetFoodItem(
        title: 'Tovuq Stripsilari',
        subtitle: 'Qarsildoq mayin tovuq bo\'laklari',
        url: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80',
        keywords: 'strips, стрипсы',
      ),
      PresetFoodItem(
        title: 'Mozzarella Tayoqchalari',
        subtitle: 'Erigan mozzarella va qarsildoq panir',
        url: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600&auto=format&fit=crop&q=80',
        keywords: 'mozzarella sticks, сырные палочки',
      ),
      PresetFoodItem(
        title: 'Piyoz Halqalari',
        subtitle: 'Oltin tusli qarsildoq halqalar',
        url: 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?w=600&auto=format&fit=crop&q=80',
        keywords: 'onion rings, луковые кольца',
      ),
      PresetFoodItem(
        title: 'Qarsildoq Qanotchalar',
        subtitle: 'Achchiq-shirin qovurilgan qanot',
        url: 'https://images.unsplash.com/photo-1527477321005-4d01d75bc660?w=600&auto=format&fit=crop&q=80',
        keywords: 'wings, крылья',
      ),
      PresetFoodItem(
        title: 'Sarimsoqli Grenkalar',
        subtitle: 'Qora nondan sarimsoqli qarsildoq',
        url: 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?w=600&auto=format&fit=crop&q=80',
        keywords: 'grenki, гренки чесночные',
      ),
    ],
  ),
  PresetFoodCategory(
    title: 'Desertlar & Muzqaymoq',
    icon: Icons.cake_rounded,
    items: [
      PresetFoodItem(
        title: 'Medovik (Asalli tort)',
        subtitle: 'Nozik asal va smetana kremi',
        url: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600&auto=format&fit=crop&q=80',
        keywords: 'medovik, медовик, honey cake, desert',
      ),
      PresetFoodItem(
        title: 'Napoleon Torti',
        subtitle: 'Qatlama xamir va vanilli nozik krem',
        url: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80',
        keywords: 'napoleon, наполеон, cake',
      ),
      PresetFoodItem(
        title: 'Qizil Baxmal (Red Velvet)',
        subtitle: 'Mayin krem-chiz va qizil biskvit',
        url: 'https://images.unsplash.com/photo-1586788680434-30d324b2d46f?w=600&auto=format&fit=crop&q=80',
        keywords: 'red velvet, красный бархат',
      ),
      PresetFoodItem(
        title: 'Chizkeyk Nyu-York',
        subtitle: 'Klassik pishirilgan qaymoqli chizkeyk',
        url: 'https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=600&auto=format&fit=crop&q=80',
        keywords: 'cheesecake, чизкейк нью йорк',
      ),
      PresetFoodItem(
        title: 'San-Sebastyan Chizkeyk',
        subtitle: 'Kuygan kremli nozik ispan chizkeyki',
        url: 'https://images.unsplash.com/photo-1535141192574-5d4897c13136?w=600&auto=format&fit=crop&q=80',
        keywords: 'san sebastian, сан себастьян',
      ),
      PresetFoodItem(
        title: 'Shokoladli Fondant',
        subtitle: 'Ichidan issiq shokolad oquvchi keks',
        url: 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=600&auto=format&fit=crop&q=80',
        keywords: 'fondant, фондан шоколадный',
      ),
      PresetFoodItem(
        title: 'Tiramisu',
        subtitle: 'Italiyacha savoyardi, kofe va maskarpone',
        url: 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=600&auto=format&fit=crop&q=80',
        keywords: 'tiramisu, тирамису',
      ),
      PresetFoodItem(
        title: 'Shokoladli Brauni',
        subtitle: 'Yong\'oqli quyuq shokoladli brauni',
        url: 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=600&auto=format&fit=crop&q=80',
        keywords: 'brownie, брауни',
      ),
      PresetFoodItem(
        title: 'Pahlava (Baklava)',
        subtitle: 'Asal va yong\'oqli sharqona pahlava',
        url: 'https://images.unsplash.com/photo-1587314168485-3236d6710814?w=600&auto=format&fit=crop&q=80',
        keywords: 'baklava, pahlava, пахлава',
      ),
      PresetFoodItem(
        title: 'Kruassan Shokoladli',
        subtitle: 'Fransuzcha mayin sariyog\'li qatlama',
        url: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=600&auto=format&fit=crop&q=80',
        keywords: 'croissant, kruassan, круассан',
      ),
      PresetFoodItem(
        title: 'Ponchiklar Assorti',
        subtitle: 'Rangli shokolad va nachinkali ponchik',
        url: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80',
        keywords: 'donuts, ponchik, пончики',
      ),
      PresetFoodItem(
        title: 'Ekler (2 dona)',
        subtitle: 'Qaymoqli vanil kremi bilan ekler',
        url: 'https://images.unsplash.com/photo-1612203985729-70726954388c?w=600&auto=format&fit=crop&q=80',
        keywords: 'eclair, ekler, эклеры',
      ),
      PresetFoodItem(
        title: 'Mevali Tort',
        subtitle: 'Yangi mevalar va yengil krem',
        url: 'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=600&auto=format&fit=crop&q=80',
        keywords: 'fruit cake, фруктовый торт',
      ),
      PresetFoodItem(
        title: 'Kapkeyk (Maffin)',
        subtitle: 'Rangli kremli shirin keks',
        url: 'https://images.unsplash.com/photo-1587668178277-295251f900ce?w=600&auto=format&fit=crop&q=80',
        keywords: 'cupcake, капкейк, маффин',
      ),
      PresetFoodItem(
        title: 'Makaron Shirinligi (3 dona)',
        subtitle: 'Fransuzcha mayin bodomli makaronlar',
        url: 'https://images.unsplash.com/photo-1569864358642-9d1684040f43?w=600&auto=format&fit=crop&q=80',
        keywords: 'macaron, макаруны',
      ),
      PresetFoodItem(
        title: 'Vafli Shirinligi',
        subtitle: 'Shokolad, muzqaymoq va mevali vafli',
        url: 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?w=600&auto=format&fit=crop&q=80',
        keywords: 'waffle, vafli, вафли',
      ),
      PresetFoodItem(
        title: 'Plombir Klassik',
        subtitle: 'Qaymoqli toza sutli oq muzqaymoq',
        url: 'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=600&auto=format&fit=crop&q=80',
        keywords: 'plombir, marojni, пломбир, ice cream',
      ),
      PresetFoodItem(
        title: 'Shokoladli Marojni',
        subtitle: 'Quyuq shokolad ta\'mi bilan',
        url: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=600&auto=format&fit=crop&q=80',
        keywords: 'chocolate ice cream, шоколадное мороженое',
      ),
      PresetFoodItem(
        title: 'Qulupnayli Marojni',
        subtitle: 'Yangi qulupnay mevalari bilan',
        url: 'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=600&auto=format&fit=crop&q=80',
        keywords: 'strawberry, клубничное мороженое',
      ),
      PresetFoodItem(
        title: 'Rojok Vanilli',
        subtitle: 'Qarsildoq vafli konusi va vanil',
        url: 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&auto=format&fit=crop&q=80',
        keywords: 'rojok, рожок ванильный',
      ),
      PresetFoodItem(
        title: 'Rojok Shokoladli',
        subtitle: 'Qarsildoq konus va shokolad glazur',
        url: 'https://images.unsplash.com/photo-1562376552-0d160a2f238d?w=600&auto=format&fit=crop&q=80',
        keywords: 'shokolad rojok, рожок шоколадный',
      ),
      PresetFoodItem(
        title: 'Eskimo Shokoladda',
        subtitle: 'Tayoqchali qalin shokolad qoplamali',
        url: 'https://images.unsplash.com/photo-1580915411954-282cb1b0d780?w=600&auto=format&fit=crop&q=80',
        keywords: 'eskimo, эскимо',
      ),
      PresetFoodItem(
        title: 'Eskimo Yong\'oqli',
        subtitle: 'Maydalangan yong\'oq va shokolad',
        url: 'https://images.unsplash.com/photo-1505394033641-40c6ad1178d7?w=600&auto=format&fit=crop&q=80',
        keywords: 'eskimo yong\'oq, эскимо с орехами',
      ),
      PresetFoodItem(
        title: 'Sundae Karamelli',
        subtitle: 'Iliq karamel sousi va yong\'oqlar',
        url: 'https://images.unsplash.com/photo-1570197788417-0e82375c9371?w=600&auto=format&fit=crop&q=80',
        keywords: 'sundae caramel, сандей карамель',
      ),
      PresetFoodItem(
        title: 'Sundae Qulupnayli',
        subtitle: 'Qulupnay djem va qaymoqli marojni',
        url: 'https://images.unsplash.com/photo-1560008581-09826d1de69e?w=600&auto=format&fit=crop&q=80',
        keywords: 'sundae strawberry, сандей клубничный',
      ),
      PresetFoodItem(
        title: 'Donali Sharik Marojni',
        subtitle: '3 xil ta\'m shariklari likopchada',
        url: 'https://images.unsplash.com/photo-1516559828984-fb3b99548b21?w=600&auto=format&fit=crop&q=80',
        keywords: 'sharik marojni, шарики мороженого',
      ),
      PresetFoodItem(
        title: 'Oreo Muzqaymoq',
        subtitle: 'Maydalangan Oreo pechenyelari bilan',
        url: 'https://images.unsplash.com/photo-1587314168485-3236d6710814?w=600&auto=format&fit=crop&q=80',
        keywords: 'oreo, мороженое орео',
      ),
      PresetFoodItem(
        title: 'Pista Muzqaymoq',
        subtitle: 'Haqiqiy xushbo\'y pista ta\'mi',
        url: 'https://images.unsplash.com/photo-1579954115545-a95591f28bfc?w=600&auto=format&fit=crop&q=80',
        keywords: 'pistachio, фисташковое мороженое',
      ),
      PresetFoodItem(
        title: 'Bananli Split',
        subtitle: 'Banan, 3 sharik marojni va qaymoq',
        url: 'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=600&auto=format&fit=crop&q=80',
        keywords: 'banana split, банановый сплит',
      ),
      PresetFoodItem(
        title: 'Mango Sorbet',
        subtitle: '100% tetiklantiruvchi mevali muz',
        url: 'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=600&auto=format&fit=crop&q=80',
        keywords: 'sorbet, mango, манго сорбет',
      ),
    ],
  ),
  PresetFoodCategory(
    title: 'Non va yopgichlar',
    icon: Icons.breakfast_dining_rounded,
    items: [
      PresetFoodItem(
        title: 'Issiq Tandir Non',
        subtitle: 'Tandirda pishgan shirmoy non',
        url: 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=600&auto=format&fit=crop&q=80',
        keywords: 'non, tandir non, тандырный хлеб, лепешка, bread',
      ),
      PresetFoodItem(
        title: 'Samarqand Patir Noni',
        subtitle: 'Yog\'li va qalin an\'anaviy Samarqand patir',
        url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80',
        keywords: 'patir, патыр, самаркандский патыр',
      ),
      PresetFoodItem(
        title: 'Kunjutli Patir',
        subtitle: 'Kunjut sepilgan xushbo\'y non',
        url: 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=600&auto=format&fit=crop&q=80',
        keywords: 'kunjut, кунжутный патыр',
      ),
      PresetFoodItem(
        title: 'Go\'shtli Non (Patir)',
        subtitle: 'Tandirda pishgan qiymali patir',
        url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80',
        keywords: 'go\'shtli non, мясная лепешка',
      ),
      PresetFoodItem(
        title: 'Qatlama Non',
        subtitle: 'Sariyog\'li qavat-qavat mayin qatlama',
        url: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=600&auto=format&fit=crop&q=80',
        keywords: 'qatlama, катлама non',
      ),
      PresetFoodItem(
        title: 'Jizzali Patir',
        subtitle: 'Dumba va jizza bilan to\'ldirilgan',
        url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80',
        keywords: 'jizza, патыр с шкварками',
      ),
      PresetFoodItem(
        title: 'Shirin Kulcha Non',
        subtitle: 'Sut va sariyog\'li kichik kulcha',
        url: 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=600&auto=format&fit=crop&q=80',
        keywords: 'kulcha, кульча',
      ),
      PresetFoodItem(
        title: 'Yupqa Lavash Noni',
        subtitle: 'Yupqa buklanuvchi lavash yaprog\'i',
        url: 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&auto=format&fit=crop&q=80',
        keywords: 'lavash non, тонкий лаваш',
      ),
      PresetFoodItem(
        title: 'Pita Noni (3 dona)',
        subtitle: 'Ichiga qiyma solishga qulay pita',
        url: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80',
        keywords: 'pita, пита',
      ),
      PresetFoodItem(
        title: 'Qarsildoq Baget',
        subtitle: 'Fransuzcha uzun qarsildoq oq non',
        url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80',
        keywords: 'baget, baguette, багет',
      ),
      PresetFoodItem(
        title: 'Sarimsoqli Baqet Non',
        subtitle: 'Sariyog\' va sarimsoq bilan qovurilgan',
        url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80',
        keywords: 'garlic bread, чесночный багет',
      ),
      PresetFoodItem(
        title: 'Pishloqli Fokatsha',
        subtitle: 'Rozmarin va zaytun yog\'li italiyan noni',
        url: 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=600&auto=format&fit=crop&q=80',
        keywords: 'focaccia, фокачча',
      ),
      PresetFoodItem(
        title: 'Tandir Joxori Non',
        subtitle: 'Makkajo\'xori unidan tayyorlangan',
        url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80',
        keywords: 'joxori, кукурузный хлеб',
      ),
      PresetFoodItem(
        title: 'Qora Donli Non',
        subtitle: 'Foydali to\'la donli javdar noni',
        url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80',
        keywords: 'qora non, ржаной хлеб',
      ),
      PresetFoodItem(
        title: 'Toster Noni (Qovurilgan)',
        subtitle: 'Sariyog\'da qizargan qarsildoq tost',
        url: 'https://images.unsplash.com/photo-1554433607-66b5efe9d304?w=600&auto=format&fit=crop&q=80',
        keywords: 'toast, тост',
      ),
      PresetFoodItem(
        title: 'Non Savatchasi Assorti',
        subtitle: 'Tandir non, patir va kulchalar jamlanmasi',
        url: 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=600&auto=format&fit=crop&q=80',
        keywords: 'savatcha, хлебная корзина',
      ),
    ],
  ),
  PresetFoodCategory(
    title: 'Ichimliklar',
    icon: Icons.local_drink_rounded,
    items: [
      PresetFoodItem(
        title: 'Coca-Cola 0.5 L',
        subtitle: '0.5 litr muzdek plastik idish',
        url: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80',
        keywords: 'cola, kola, кола, coca-cola, 0.5, 0.5l, 0,5, 0,5l, 0.5 l',
        brand: 'Coca-Cola',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Coca-Cola 1.0 L',
        subtitle: '1.0 litr plastik idish',
        url: 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=600&auto=format&fit=crop&q=80',
        keywords: 'cola, kola, кола, coca-cola, 1l, 1.0l, 1, 1.0, 1 l',
        brand: 'Coca-Cola',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Coca-Cola 1.5 L',
        subtitle: '1.5 litr katta gazlangan ichimlik',
        url: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600&auto=format&fit=crop&q=80',
        keywords: 'cola, kola, кола, coca-cola, 1.5, 1.5l, 1,5, 1,5l, 1.5 l',
        brand: 'Coca-Cola',
        volume: '1.5 L',
      ),
      PresetFoodItem(
        title: 'Coca-Cola 2.0 L',
        subtitle: '2.0 litr oilaviy katta idish',
        url: 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=600&auto=format&fit=crop&q=80',
        keywords: 'cola, kola, кола, coca-cola, 2l, 2.0l, 2, 2.0, 2 l',
        brand: 'Coca-Cola',
        volume: '2.0 L',
      ),
      PresetFoodItem(
        title: 'Coca-Cola Banka 0.33 L',
        subtitle: '330 ml qulay temir banka',
        url: 'https://images.unsplash.com/photo-1567103472667-6898f3a79cf2?w=600&auto=format&fit=crop&q=80',
        keywords: 'cola, kola, кола, coca-cola, banka, 0.33, 0.33l, can',
        brand: 'Coca-Cola',
        volume: '0.33 L',
      ),
      PresetFoodItem(
        title: 'Coca-Cola Zero 0.5 L',
        subtitle: '0.5 litr shakarsiz klassik ta\'m',
        url: 'https://images.unsplash.com/photo-1596803244618-8dbee441d70b?w=600&auto=format&fit=crop&q=80',
        keywords: 'zero, ziro, shakarsiz, 0.5, 0.5l, кола зеро',
        brand: 'Coca-Cola',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Coca-Cola Zero 1.0 L',
        subtitle: '1.0 litr shakarsiz ichimlik',
        url: 'https://images.unsplash.com/photo-1596803244618-8dbee441d70b?w=600&auto=format&fit=crop&q=80',
        keywords: 'zero, ziro, 1l, 1.0l, 1, кола зеро',
        brand: 'Coca-Cola',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Coca-Cola Zero 1.5 L',
        subtitle: '1.5 litr shakarsiz katta idish',
        url: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80',
        keywords: 'zero, ziro, 1.5, 1.5l, 1,5, кола зеро',
        brand: 'Coca-Cola',
        volume: '1.5 L',
      ),
      PresetFoodItem(
        title: 'Coca-Cola Zero 2.0 L',
        subtitle: '2.0 litr shakarsiz oilaviy idish',
        url: 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=600&auto=format&fit=crop&q=80',
        keywords: 'zero, ziro, 2l, 2.0l, 2, кола зеро',
        brand: 'Coca-Cola',
        volume: '2.0 L',
      ),
      PresetFoodItem(
        title: 'Coca-Cola Shisha 0.25 L',
        subtitle: 'Klassik shisha idishdagi muzdek kola',
        url: 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=600&auto=format&fit=crop&q=80',
        keywords: 'shisha, glass, 0.25, 0.25l, стекло',
        brand: 'Coca-Cola',
        volume: '0.25 L',
      ),
      PresetFoodItem(
        title: 'Coca-Cola Muz Bilan',
        subtitle: 'Muzli stakanda va limon bilan',
        url: 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=600&auto=format&fit=crop&q=80',
        keywords: 'muz, ice, кола со льдом, limon',
        brand: 'Coca-Cola',
      ),
      PresetFoodItem(
        title: 'Fanta Apelsin 0.5 L',
        subtitle: '0.5 litr mayin apelsin ta\'mi',
        url: 'https://images.unsplash.com/photo-1624638760978-7517178385ea?w=600&auto=format&fit=crop&q=80',
        keywords: 'fanta, фанта, orange, apelsin, 0.5, 0.5l, 0,5, 0,5l',
        brand: 'Fanta',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Fanta Apelsin 1.0 L',
        subtitle: '1.0 litr apelsinli gazlangan ichimlik',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: 'fanta, фанта, 1l, 1.0l, 1, 1.0',
        brand: 'Fanta',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Fanta Apelsin 1.5 L',
        subtitle: '1.5 litr katta apelsinli ichimlik',
        url: 'https://images.unsplash.com/photo-1579268351234-073f85929562?w=600&auto=format&fit=crop&q=80',
        keywords: 'fanta, фанта, 1.5, 1.5l, 1,5, 1,5l',
        brand: 'Fanta',
        volume: '1.5 L',
      ),
      PresetFoodItem(
        title: 'Fanta Apelsin 2.0 L',
        subtitle: '2.0 litr oilaviy apelsin fanta',
        url: 'https://images.unsplash.com/photo-1624638760978-7517178385ea?w=600&auto=format&fit=crop&q=80',
        keywords: 'fanta, фанта, 2l, 2.0l, 2, 2.0',
        brand: 'Fanta',
        volume: '2.0 L',
      ),
      PresetFoodItem(
        title: 'Fanta Banka 0.33 L',
        subtitle: '330 ml qulay temir banka',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: 'fanta banka, 0.33, 0.33l, can',
        brand: 'Fanta',
        volume: '0.33 L',
      ),
      PresetFoodItem(
        title: 'Fanta Shisha 0.25 L',
        subtitle: 'Shisha idishdagi muzdek fanta',
        url: 'https://images.unsplash.com/photo-1579268351234-073f85929562?w=600&auto=format&fit=crop&q=80',
        keywords: 'fanta shisha, 0.25, 0.25l',
        brand: 'Fanta',
        volume: '0.25 L',
      ),
      PresetFoodItem(
        title: 'Fanta Tropic 0.5 L',
        subtitle: 'Tropik mevalar ta\'mi bilan',
        url: 'https://images.unsplash.com/photo-1624638760978-7517178385ea?w=600&auto=format&fit=crop&q=80',
        keywords: 'fanta tropic, тропик, 0.5, 0.5l',
        brand: 'Fanta',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Fanta Tropic 1.5 L',
        subtitle: '1.5 litr tropik mevalar ta\'mi',
        url: 'https://images.unsplash.com/photo-1579268351234-073f85929562?w=600&auto=format&fit=crop&q=80',
        keywords: 'fanta tropic, 1.5, 1.5l',
        brand: 'Fanta',
        volume: '1.5 L',
      ),
      PresetFoodItem(
        title: 'Sprite 0.5 L',
        subtitle: '0.5 litr laym va limon ta\'mli salqin ichimlik',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: 'sprite, спрайт, laym, lemon, 0.5, 0.5l, 0,5',
        brand: 'Sprite',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Sprite 1.0 L',
        subtitle: '1.0 litr plastik idish',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: 'sprite, спрайт, 1l, 1.0l, 1',
        brand: 'Sprite',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Sprite 1.5 L',
        subtitle: '1.5 litr tiniq limon ta\'mi',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: 'sprite, спрайт, 1.5, 1.5l, 1,5',
        brand: 'Sprite',
        volume: '1.5 L',
      ),
      PresetFoodItem(
        title: 'Sprite 2.0 L',
        subtitle: '2.0 litr oilaviy tetiklashtiruvchi',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: 'sprite, спрайт, 2l, 2.0l, 2',
        brand: 'Sprite',
        volume: '2.0 L',
      ),
      PresetFoodItem(
        title: 'Sprite Banka 0.33 L',
        subtitle: '330 ml temir banka',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: 'sprite banka, 0.33, can',
        brand: 'Sprite',
        volume: '0.33 L',
      ),
      PresetFoodItem(
        title: 'Sprite Shisha 0.25 L',
        subtitle: 'Klassik shisha idishda',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: 'sprite shisha, 0.25',
        brand: 'Sprite',
        volume: '0.25 L',
      ),
      PresetFoodItem(
        title: 'Sprite Zero 0.5 L',
        subtitle: '0.5 litr shakarsiz tiniq limon',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: 'sprite zero, 0.5, 0.5l, shakarsiz',
        brand: 'Sprite',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Pepsi 0.5 L',
        subtitle: '0.5 litr klassik pepsi ta\'mi',
        url: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600&auto=format&fit=crop&q=80',
        keywords: 'pepsi, пепси, cola, 0.5, 0.5l, 0,5',
        brand: 'Pepsi',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Pepsi 1.0 L',
        subtitle: '1.0 litr plastik idish',
        url: 'https://images.unsplash.com/photo-1553456558-aff63285bdd1?w=600&auto=format&fit=crop&q=80',
        keywords: 'pepsi, пепси, 1l, 1.0l, 1',
        brand: 'Pepsi',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Pepsi 1.5 L',
        subtitle: '1.5 litr katta plastik idish',
        url: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600&auto=format&fit=crop&q=80',
        keywords: 'pepsi, пепси, 1.5, 1.5l, 1,5',
        brand: 'Pepsi',
        volume: '1.5 L',
      ),
      PresetFoodItem(
        title: 'Pepsi 2.0 L',
        subtitle: '2.0 litr oilaviy pepsi',
        url: 'https://images.unsplash.com/photo-1553456558-aff63285bdd1?w=600&auto=format&fit=crop&q=80',
        keywords: 'pepsi, пепси, 2l, 2.0l, 2',
        brand: 'Pepsi',
        volume: '2.0 L',
      ),
      PresetFoodItem(
        title: 'Pepsi Banka 0.33 L',
        subtitle: '330 ml temir banka',
        url: 'https://images.unsplash.com/photo-1553456558-aff63285bdd1?w=600&auto=format&fit=crop&q=80',
        keywords: 'pepsi banka, 0.33, can',
        brand: 'Pepsi',
        volume: '0.33 L',
      ),
      PresetFoodItem(
        title: 'Pepsi Max Zero 0.5 L',
        subtitle: '0.5 litr shakarsiz pepsi',
        url: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600&auto=format&fit=crop&q=80',
        keywords: 'pepsi max, zero, 0.5, 0.5l',
        brand: 'Pepsi',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Pepsi Max Zero 1.5 L',
        subtitle: '1.5 litr shakarsiz pepsi',
        url: 'https://images.unsplash.com/photo-1553456558-aff63285bdd1?w=600&auto=format&fit=crop&q=80',
        keywords: 'pepsi max, zero, 1.5, 1.5l',
        brand: 'Pepsi',
        volume: '1.5 L',
      ),
      PresetFoodItem(
        title: 'Pepsi Shisha 0.25 L',
        subtitle: 'Shisha idishdagi muzdek pepsi',
        url: 'https://images.unsplash.com/photo-1629203851122-3726ecdf080e?w=600&auto=format&fit=crop&q=80',
        keywords: 'pepsi shisha, 0.25',
        brand: 'Pepsi',
        volume: '0.25 L',
      ),
      PresetFoodItem(
        title: 'Mirinda 0.5 L',
        subtitle: '0.5 litr yorqin apelsin ta\'mi',
        url: 'https://images.unsplash.com/photo-1624638760978-7517178385ea?w=600&auto=format&fit=crop&q=80',
        keywords: 'mirinda, миринда, 0.5, 0.5l, orange',
        brand: 'Mirinda',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Mirinda 1.0 L',
        subtitle: '1.0 litr plastik idish',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: 'mirinda, миринда, 1l, 1.0l, 1',
        brand: 'Mirinda',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Mirinda 1.5 L',
        subtitle: '1.5 litr katta apelsin ta\'mi',
        url: 'https://images.unsplash.com/photo-1579268351234-073f85929562?w=600&auto=format&fit=crop&q=80',
        keywords: 'mirinda, миринда, 1.5, 1.5l',
        brand: 'Mirinda',
        volume: '1.5 L',
      ),
      PresetFoodItem(
        title: 'Mirinda 2.0 L',
        subtitle: '2.0 litr oilaviy idish',
        url: 'https://images.unsplash.com/photo-1624638760978-7517178385ea?w=600&auto=format&fit=crop&q=80',
        keywords: 'mirinda, миринда, 2l, 2.0l, 2',
        brand: 'Mirinda',
        volume: '2.0 L',
      ),
      PresetFoodItem(
        title: 'Mirinda Banka 0.33 L',
        subtitle: '330 ml temir banka',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: 'mirinda banka, 0.33',
        brand: 'Mirinda',
        volume: '0.33 L',
      ),
      PresetFoodItem(
        title: '7UP 0.5 L',
        subtitle: '0.5 litr limon-laym tetikligi',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: '7up, севенап, 0.5, 0.5l, limon',
        brand: '7UP',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: '7UP 1.0 L',
        subtitle: '1.0 litr plastik idish',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: '7up, севенап, 1l, 1.0l, 1',
        brand: '7UP',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: '7UP 1.5 L',
        subtitle: '1.5 litr katta tetiklashtiruvchi',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: '7up, севенап, 1.5, 1.5l',
        brand: '7UP',
        volume: '1.5 L',
      ),
      PresetFoodItem(
        title: '7UP 2.0 L',
        subtitle: '2.0 litr oilaviy idish',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: '7up, севенап, 2l, 2.0l, 2',
        brand: '7UP',
        volume: '2.0 L',
      ),
      PresetFoodItem(
        title: '7UP Banka 0.33 L',
        subtitle: '330 ml temir banka',
        url: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80',
        keywords: '7up banka, 0.33',
        brand: '7UP',
        volume: '0.33 L',
      ),
      PresetFoodItem(
        title: 'Dena Olma 1.0 L',
        subtitle: '100% tabiiy olma sharbati',
        url: 'https://images.unsplash.com/photo-1568651316335-e106ea46261c?w=600&auto=format&fit=crop&q=80',
        keywords: 'dena, дена, olma, яблоко, сок, 1l, 1.0l',
        brand: 'Dena',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Dena Shaftoli 1.0 L',
        subtitle: 'Quyuq va xushbo\'y shaftoli sharbati',
        url: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80',
        keywords: 'dena, дена, shaftoli, персик, 1l',
        brand: 'Dena',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Dena Olcha 1.0 L',
        subtitle: 'Shirin-nordon olcha sharbati',
        url: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80',
        keywords: 'dena, дена, olcha, вишня, 1l',
        brand: 'Dena',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Dena Multimeva 1.0 L',
        subtitle: 'Turli mevalar uyg\'unligi',
        url: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80',
        keywords: 'dena, дена, multimeva, мультифрукт, 1l',
        brand: 'Dena',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Dena Apelsin 1.0 L',
        subtitle: 'Apelsin vitaminli sharbati',
        url: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80',
        keywords: 'dena, дена, apelsin, апельсин, 1l',
        brand: 'Dena',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Dena Anor 1.0 L',
        subtitle: 'Tabiiy toza anor sharbati',
        url: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=600&auto=format&fit=crop&q=80',
        keywords: 'dena, дена, anor, гранат, 1l',
        brand: 'Dena',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Dena Olma 0.5 L',
        subtitle: '0.5 litr qulay idishda olma',
        url: 'https://images.unsplash.com/photo-1568651316335-e106ea46261c?w=600&auto=format&fit=crop&q=80',
        keywords: 'dena, дена, olma, 0.5, 0.5l',
        brand: 'Dena',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Gazsiz Suv 0.5 L',
        subtitle: 'Toza tog\' buloq suvi',
        url: 'https://images.unsplash.com/photo-1548839140-29a749e1bc4e?w=600&auto=format&fit=crop&q=80',
        keywords: 'suv, water, вода без газа, 0.5, 0.5l',
        brand: 'Suv',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Gazsiz Suv 1.0 L',
        subtitle: '1 litr toza ichimlik suvi',
        url: 'https://images.unsplash.com/photo-1559839914-ba2a578a05c3?w=600&auto=format&fit=crop&q=80',
        keywords: 'suv, water, 1l, 1.0l, вода',
        brand: 'Suv',
        volume: '1.0 L',
      ),
      PresetFoodItem(
        title: 'Gazsiz Suv 1.5 L',
        subtitle: '1.5 litr toza ichimlik suvi',
        url: 'https://images.unsplash.com/photo-1559839914-ba2a578a05c3?w=600&auto=format&fit=crop&q=80',
        keywords: 'suv, water, 1.5, 1.5l, вода',
        brand: 'Suv',
        volume: '1.5 L',
      ),
      PresetFoodItem(
        title: 'Gazli Suv 0.5 L',
        subtitle: 'Salqin gazlangan mineral suv',
        url: 'https://images.unsplash.com/photo-1550572017-edd951aa8f72?w=600&auto=format&fit=crop&q=80',
        keywords: 'gazli suv, sparkling water, вода с газом, 0.5',
        brand: 'Suv',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Gazli Suv 1.5 L',
        subtitle: 'Katta gazli mineral suv',
        url: 'https://images.unsplash.com/photo-1550572017-edd951aa8f72?w=600&auto=format&fit=crop&q=80',
        keywords: 'gazli suv, 1.5, 1.5l',
        brand: 'Suv',
        volume: '1.5 L',
      ),
      PresetFoodItem(
        title: 'Borjomi 0.5 L',
        subtitle: 'Shifobaxsh mineral gazlangan suv',
        url: 'https://images.unsplash.com/photo-1527661591475-527312dd65f5?w=600&auto=format&fit=crop&q=80',
        keywords: 'borjomi, боржоми, mineral, 0.5',
        brand: 'Suv',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Espresso',
        subtitle: 'Klassik to\'q qahva',
        url: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600&auto=format&fit=crop&q=80',
        keywords: 'espresso, эспрессо, kofe, qahva, coffee',
        brand: 'Qahva',
      ),
      PresetFoodItem(
        title: 'Amerikano',
        subtitle: 'Issiq va yumshoq espresso suvi bilan',
        url: 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&auto=format&fit=crop&q=80',
        keywords: 'americano, американо, kofe, qahva',
        brand: 'Qahva',
      ),
      PresetFoodItem(
        title: 'Kapuchino',
        subtitle: 'Qalin va mayin sutli ko\'pik bilan',
        url: 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?w=600&auto=format&fit=crop&q=80',
        keywords: 'cappuccino, капучино, kofe',
        brand: 'Qahva',
      ),
      PresetFoodItem(
        title: 'Latte',
        subtitle: 'Sutli mayin qahva nozik ta\'m',
        url: 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=600&auto=format&fit=crop&q=80',
        keywords: 'latte, латте, kofe',
        brand: 'Qahva',
      ),
      PresetFoodItem(
        title: 'Mokkachino',
        subtitle: 'Shokolad va qahva uyg\'unligi',
        url: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80',
        keywords: 'mochaccino, моккачино, shokolad',
        brand: 'Qahva',
      ),
      PresetFoodItem(
        title: 'Raf Qahva',
        subtitle: 'Qaymoq va vanilli mayin qahva',
        url: 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600&auto=format&fit=crop&q=80',
        keywords: 'raf, раф кофе',
        brand: 'Qahva',
      ),
      PresetFoodItem(
        title: 'Muzli Kofe (Ice Latte)',
        subtitle: 'Muzdek va tetiklashtiruvchi latte',
        url: 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?w=600&auto=format&fit=crop&q=80',
        keywords: 'ice latte, американо со льдом, kofe',
        brand: 'Qahva',
      ),
      PresetFoodItem(
        title: 'Issiq Shokolad (Kakao)',
        subtitle: 'Quyuq shokoladli issiq ichimlik',
        url: 'https://images.unsplash.com/photo-1542990253-0d0f5be5f0ed?w=600&auto=format&fit=crop&q=80',
        keywords: 'kakao, какао, горячий шоколад',
        brand: 'Qahva',
      ),
      PresetFoodItem(
        title: 'Ko\'k Choy (Choynak)',
        subtitle: 'Klassik 95 ko\'k choy choynakda',
        url: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80',
        keywords: 'choy, tea, зеленый чай, ko\'k choy',
        brand: 'Choy',
      ),
      PresetFoodItem(
        title: 'Qora Choy (Choynak)',
        subtitle: 'Xushbo\'y bargli qora choy',
        url: 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=600&auto=format&fit=crop&q=80',
        keywords: 'qora choy, черный чай, tea',
        brand: 'Choy',
      ),
      PresetFoodItem(
        title: 'Limonli Choy',
        subtitle: 'Yangi limon bo\'laklari va asal bilan',
        url: 'https://images.unsplash.com/photo-1556881286-fc6915169721?w=600&auto=format&fit=crop&q=80',
        keywords: 'limonli choy, чай с лимоном',
        brand: 'Choy',
      ),
      PresetFoodItem(
        title: 'Tog\' Choyi (Giyohli)',
        subtitle: 'Kiyiko\'t va tog\' yalpizi bilan',
        url: 'https://images.unsplash.com/photo-1597481499750-3e6b22637e12?w=600&auto=format&fit=crop&q=80',
        keywords: 'tog\' choyi, горный чай, giyoh',
        brand: 'Choy',
      ),
      PresetFoodItem(
        title: 'Mevali Choy',
        subtitle: 'Olma, apelsin va rezavorlar',
        url: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80',
        keywords: 'mevali choy, фруктовый чай',
        brand: 'Choy',
      ),
      PresetFoodItem(
        title: 'Zanjabil Choy (Asalli)',
        subtitle: 'Imbir, yangi asal va limon',
        url: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80',
        keywords: 'zanjabil, имбирный чай, ginger',
        brand: 'Choy',
      ),
      PresetFoodItem(
        title: 'Qulupnayli Choy',
        subtitle: 'Yangi qulupnay va yalpizli choy',
        url: 'https://images.unsplash.com/photo-1556881286-fc6915169721?w=600&auto=format&fit=crop&q=80',
        keywords: 'qulupnay choy, клубничный чай',
        brand: 'Choy',
      ),
      PresetFoodItem(
        title: 'Apelsin Sharbati (Fresh)',
        subtitle: 'Yangi siqilgan tabiiy apelsin',
        url: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80',
        keywords: 'fresh, фреш апельсиновый, sharbat',
        brand: 'Sharbat',
      ),
      PresetFoodItem(
        title: 'Olma Sharbati (Fresh)',
        subtitle: 'Yangi siqilgan tiniq olma',
        url: 'https://images.unsplash.com/photo-1568651316335-e106ea46261c?w=600&auto=format&fit=crop&q=80',
        keywords: 'fresh, яблочный фреш',
        brand: 'Sharbat',
      ),
      PresetFoodItem(
        title: 'Anor Sharbati (Fresh)',
        subtitle: 'Toza tabiiy anor sharbati',
        url: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=600&auto=format&fit=crop&q=80',
        keywords: 'fresh, гранатовый сок',
        brand: 'Sharbat',
      ),
      PresetFoodItem(
        title: 'Klassik Mojito',
        subtitle: 'Laym, yangi yalpiz va muz',
        url: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80',
        keywords: 'mojito, мохито классический, laym',
        brand: 'Limonad',
      ),
      PresetFoodItem(
        title: 'Qulupnayli Mojito',
        subtitle: 'Qulupnay va yalpizli salqin ichimlik',
        url: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80',
        keywords: 'mojito strawberry, мохито клубничный',
        brand: 'Limonad',
      ),
      PresetFoodItem(
        title: 'Uy Limonadi',
        subtitle: 'Sitrus mevalari va muz bilan',
        url: 'https://images.unsplash.com/photo-1621263764928-df1444c5e859?w=600&auto=format&fit=crop&q=80',
        keywords: 'limonad, лимонад домашний',
        brand: 'Limonad',
      ),
      PresetFoodItem(
        title: 'Tarxun',
        subtitle: 'Xushbo\'y yashil o\'tli an\'anaviy limonad',
        url: 'https://images.unsplash.com/photo-1536935338788-846bb9981813?w=600&auto=format&fit=crop&q=80',
        keywords: 'tarxun, тархун',
        brand: 'Limonad',
      ),
      PresetFoodItem(
        title: 'Dyushes (Nok limonadi)',
        subtitle: 'Shirin nok lazzatli tetiklashtiruvchi',
        url: 'https://images.unsplash.com/photo-1556881286-fc6915169721?w=600&auto=format&fit=crop&q=80',
        keywords: 'dyushes, дюшес, nok',
        brand: 'Limonad',
      ),
      PresetFoodItem(
        title: 'Berry Mix Smoothie',
        subtitle: 'Rezavor mevali vitaminli smuzi',
        url: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=600&auto=format&fit=crop&q=80',
        keywords: 'smoothie, smuzi, смузи',
        brand: 'Limonad',
      ),
      PresetFoodItem(
        title: 'Red Bull Energetik',
        subtitle: '0.25 litr energiya beruvchi ichimlik',
        url: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80',
        keywords: 'red bull, ред булл, энергетик, 0.25',
        brand: 'Energetik',
        volume: '0.25 L',
      ),
      PresetFoodItem(
        title: 'Flash Energetik',
        subtitle: '0.5 litr tetiklashtiruvchi energetik',
        url: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80',
        keywords: 'flash, флеш, энергетик, 0.5, 0.5l',
        brand: 'Energetik',
        volume: '0.5 L',
      ),
      PresetFoodItem(
        title: 'Muzqaymoqli Milkshake Vanil',
        subtitle: 'Mayin qaymoqli va vanilli sutli kokteyl',
        url: 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&auto=format&fit=crop&q=80',
        keywords: 'milkshake, милкшейк ванильный, kokteyl',
        brand: 'Milkshake',
      ),
      PresetFoodItem(
        title: 'Muzqaymoqli Milkshake Shokolad',
        subtitle: 'Quyuq shokoladli sut kokteyli',
        url: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=600&auto=format&fit=crop&q=80',
        keywords: 'milkshake chocolate, шоколадный милкшейк',
        brand: 'Milkshake',
      ),
      PresetFoodItem(
        title: 'Muzqaymoqli Milkshake Qulupnay',
        subtitle: 'Yangi qulupnayli shirin kokteyl',
        url: 'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=600&auto=format&fit=crop&q=80',
        keywords: 'milkshake strawberry, клубничный милкшейк',
        brand: 'Milkshake',
      ),
    ],
  ),
];


class PresetImagesPickerDialog extends StatefulWidget {
  const PresetImagesPickerDialog({super.key});

  @override
  State<PresetImagesPickerDialog> createState() => _PresetImagesPickerDialogState();
}


class _PresetImagesPickerDialogState extends State<PresetImagesPickerDialog> {
  int _selectedCategoryIndex = 0;
  String? _selectedImageUrl;
  String? _selectedItemName;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Filters for drinks
  String? _selectedBrand;
  String? _selectedVolume;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectAndFinish(PresetFoodItem item) {
    Navigator.pop(context, {
      'url': item.url,
      'name': item.title,
    });
  }

  bool _matchesSearch(PresetFoodItem item, String q) {
    if (q.isEmpty) return true;
    final cleanQ = q.toLowerCase().replaceAll(',', '.').replaceAll(' l', 'l').trim();
    final parts = cleanQ.split(' ').where((s) => s.isNotEmpty).toList();

    bool matchAll = true;
    for (final p in parts) {
      final t = item.title.toLowerCase().replaceAll(',', '.').replaceAll(' l', 'l');
      final s = (item.subtitle ?? '').toLowerCase().replaceAll(',', '.').replaceAll(' l', 'l');
      final k = (item.keywords ?? '').toLowerCase().replaceAll(',', '.').replaceAll(' l', 'l');
      final b = (item.brand ?? '').toLowerCase().replaceAll(',', '.').replaceAll(' l', 'l');
      final v = (item.volume ?? '').toLowerCase().replaceAll(',', '.').replaceAll(' l', 'l');

      if (!t.contains(p) && !s.contains(p) && !k.contains(p) && !b.contains(p) && !v.contains(p)) {
        matchAll = false;
        break;
      }
    }
    return matchAll;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCategory = presetFoodLibraries[_selectedCategoryIndex];
    final isSearching = _searchQuery.trim().isNotEmpty;
    final isDrinkCategory = activeCategory.title.toLowerCase().contains('ichimlik') ||
        activeCategory.title.toLowerCase().contains('suv') ||
        activeCategory.title.toLowerCase().contains('coca') ||
        activeCategory.title.toLowerCase().contains('fanta');

    final List<PresetFoodItem> displayedItems;
    if (isSearching) {
      final q = _searchQuery.trim();
      displayedItems = presetFoodLibraries
          .expand((c) => c.items)
          .where((item) => _matchesSearch(item, q))
          .toList();
    } else {
      displayedItems = activeCategory.items.where((item) {
        if (_selectedBrand != null && item.brand != _selectedBrand) return false;
        if (_selectedVolume != null && item.volume != _selectedVolume) return false;
        return true;
      }).toList();
    }

    // Available brands and volumes for drink category
    final availableBrands = isDrinkCategory
        ? [
            'Barchasi',
            'Coca-Cola',
            'Fanta',
            'Sprite',
            'Pepsi',
            'Mirinda',
            '7UP',
            'Dena',
            'Suv',
            'Qahva',
            'Choy',
            'Sharbat',
            'Limonad',
          ]
        : <String>[];

    final availableVolumes = isDrinkCategory
        ? ['Barchasi', '0.25 L', '0.33 L', '0.5 L', '1.0 L', '1.5 L', '2.0 L']
        : <String>[];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFA000), Color(0xFFFFB300)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFA000).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.collections_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Tayyor taom va ichimlik rasmlari',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: kDarkYellow.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Katalog',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: kDarkYellow,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rasmni tanlang yoki qidiring (ikki marta bosib darhol tanlash mumkin)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Box
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty
                        ? const Color(0xFFFFA000)
                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(const Duration(milliseconds: 160), () {
                      if (mounted) setState(() => _searchQuery = val);
                    });
                  },
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Taom yoki ichimlik qidirish (masalan: 1.5L, shaurma, lavash, кола, osh)...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: _searchQuery.isNotEmpty ? const Color(0xFFFFA000) : Colors.grey,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Categories Horizontal Bar
              if (!isSearching)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List.generate(presetFoodLibraries.length, (i) {
                      final cat = presetFoodLibraries[i];
                      final isSel = i == _selectedCategoryIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategoryIndex = i;
                              _selectedBrand = null;
                              _selectedVolume = null;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? (isDark ? const Color(0xFFFFA000) : const Color(0xFF0F172A))
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSel
                                    ? Colors.transparent
                                    : (isDark ? Colors.white12 : Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat.icon,
                                  size: 16,
                                  color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cat.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : (isDark ? Colors.white12 : Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${cat.items.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list_rounded, size: 16, color: kDarkYellow),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Qidiruv natijalari: ${displayedItems.length} ta mahsulot topildi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Sub-filters for Drinks: Brand & Volume
              if (!isSearching && isDrinkCategory) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Brand Chips
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: availableBrands.map((b) {
                            final isAll = b == 'Barchasi';
                            final isSel = isAll ? _selectedBrand == null : _selectedBrand == b;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(b, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                                selected: isSel,
                                selectedColor: const Color(0xFFFFA000).withValues(alpha: 0.25),
                                visualDensity: VisualDensity.compact,
                                onSelected: (sel) {
                                  setState(() {
                                    _selectedBrand = isAll ? null : (sel ? b : null);
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Volume Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: availableVolumes.map((v) {
                      final isAll = v == 'Barchasi';
                      final isSel = isAll ? _selectedVolume == null : _selectedVolume == v;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(v, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                          selected: isSel,
                          selectedColor: Colors.blueAccent.withValues(alpha: 0.25),
                          visualDensity: VisualDensity.compact,
                          onSelected: (sel) {
                            setState(() {
                              _selectedVolume = isAll ? null : (sel ? v : null);
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Items Grid
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: displayedItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white30 : Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'Hech narsa topilmadi',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Boshqa so\'z yoki o\'lcham (0.5L, 1.5L) bilan qidirib ko\'ring',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth <= 50 || constraints.maxHeight <= 0) return const SizedBox.shrink();
                            final count = (constraints.maxWidth / 120).floor().clamp(1, 4);
                            return GridView.builder(
                              itemCount: displayedItems.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: count,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.15,
                              ),
                              itemBuilder: (context, idx) {
                            final item = displayedItems[idx];
                            final isSelected = _selectedImageUrl == item.url;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedImageUrl = item.url;
                                  _selectedItemName = item.title;
                                });
                              },
                              onDoubleTap: () => _selectAndFinish(item),
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Image with fallback
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      item.url,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                                          child: const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.restaurant_rounded, color: Colors.grey.shade400, size: 28),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.title,
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Dark Bottom Gradient with Title & Subtitle
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.9),
                                            Colors.black.withValues(alpha: 0.5),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              shadows: [
                                                Shadow(blurRadius: 4, color: Colors.black),
                                              ],
                                            ),
                                          ),
                                          if (item.subtitle != null) ...[
                                            const SizedBox(height: 1),
                                            Text(
                                              item.subtitle!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.8),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Selection ring / badge
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFFFFA000) : Colors.transparent,
                                        width: 3,
                                      ),
                                      color: isSelected
                                          ? const Color(0xFFFFA000).withValues(alpha: 0.15)
                                          : Colors.transparent,
                                    ),
                                  ),

                                  // Checkmark badge in corner
                                  if (isSelected)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFA000),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Bekor qilish'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        _selectedItemName != null ? '«$_selectedItemName» tanlash' : 'Rasmni tanlash',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _selectedImageUrl == null
                          ? null
                          : () {
                              Navigator.pop(context, {
                                'url': _selectedImageUrl,
                                'name': _selectedItemName,
                              });
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
