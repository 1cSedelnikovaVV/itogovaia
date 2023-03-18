﻿Функция ОпределитьКурс(Дата, Валюта) экспорт 
	
	Если Валюта <> Справочники.Валюты.Рубль Тогда  				
		ВалютаСтруктура = Новый Структура;
		ВалютаСтруктура.Вставить("Валюта",Валюта);
		
		Курс = РегистрыСведений.КурсыВалют.ПолучитьПоследнее(Дата,ВалютаСтруктура).Курс;   		
	Иначе // если в рублях
		Курс = 1;
	КонецЕсли; 
	
	Возврат Курс;
КонецФункции  



Функция НайтиЦену(Дата, Номенклатура, ВидЦены, Валюта) экспорт 
	
	Если ЗначениеЗаполнено(Валюта) Тогда		
		//Вернуть цену с учетом курса указанной в документе валюты
		Курс = ОпределитьКурс(Дата,Валюта); 
		Если Курс <> 0 Тогда 
			//Получить из регистра сведений ЦеныНоменклатуры последнее значение цены в разрезе номенклатуры и вида цены
			СтруктураОтбор = Новый Структура;
			СтруктураОтбор.Вставить("Номенклатура", Номенклатура);   
			СтруктураОтбор.Вставить("ВидЦены", ВидЦены); 
			
			Цена = РегистрыСведений.ЦеныНоменклатуры.ПолучитьПоследнее(Дата,СтруктураОтбор).Цена / Курс; 
 
			Возврат Цена; 
		Иначе	
			Сообщить("Курс " + Валюта + " не задан!"); 
			Возврат 0;
		КонецЕсли;
	Иначе
		Возврат 0;
	КонецЕсли;
	
КонецФункции
