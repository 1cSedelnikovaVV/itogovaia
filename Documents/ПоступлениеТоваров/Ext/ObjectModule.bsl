﻿Процедура ПередЗаписью(Отказ, РежимЗаписи, РежимПроведения)    
	// Сумма по табличной части товара    
	ИтоговаяСумма = Товары.Итог("Стоимость");                    	
КонецПроцедуры

Процедура ОбработкаПроведения(Отказ, Режим)    
	
	//Узнать курс указанной в документе валюты. Вызов общего модуля
	КурсВалюты = РасчетныеПроцедурыСервер.ОпределитьКурс(Дата, Валюта);  	
	Если КурсВалюты = 0 Тогда		
		Сообщить("Курс " + Валюта + " не задан!"); 
		//отказаться от проведения документа и выйти из процедуры
		Отказ = Истина;
		Возврат;			
	КонецЕсли;   
	
	
	Движения.ТоварыНаСкладах.Записывать = Истина;
	Движения.Хозрасчетный.Записывать = Истина;  
	
	
	Запрос = Новый Запрос;
	Запрос.Текст = 
		"ВЫБРАТЬ
		|	ПоступлениеТоваровТовары.Номенклатура КАК Номенклатура,
		|	СРЕДНЕЕ(ПоступлениеТоваровТовары.ЦенаЗакупочная) КАК ЦенаЗакупочная,
		|	СУММА(ПоступлениеТоваровТовары.Количество) КАК Количество,
		|	СУММА(ПоступлениеТоваровТовары.Стоимость) КАК Стоимость
		|ИЗ
		|	Документ.ПоступлениеТоваров.Товары КАК ПоступлениеТоваровТовары
		|ГДЕ
		|	ПоступлениеТоваровТовары.Ссылка = &Ссылка
		|
		|СГРУППИРОВАТЬ ПО
		|	ПоступлениеТоваровТовары.Номенклатура";
	
	Запрос.УстановитьПараметр("Ссылка", Ссылка);
	
	РезультатЗапроса = Запрос.Выполнить();
	
	Выборка = РезультатЗапроса.Выбрать();
	
	Пока Выборка.Следующий() Цикл     
		
		// регистр ТоварыНаСкладах Приход
		Движение = Движения.ТоварыНаСкладах.Добавить();
		Движение.ВидДвижения = ВидДвиженияНакопления.Приход;
		Движение.Период = Дата;
		Движение.Номенклатура = Выборка.Номенклатура;
		Движение.Склад = Склад;
		Движение.Партия = Ссылка;
		Движение.Количество = Выборка.Количество;
		Движение.Сумма = Выборка.Стоимость * КурсВалюты;  
		
		// регистр Хозрасчетный 
		//Дт41.01 - Кт60.01
		Движение = Движения.Хозрасчетный.Добавить();
		Движение.СчетДт = ПланыСчетов.Хозрасчетный.ТоварыНаСкладах;
		Движение.СчетКт = ПланыСчетов.Хозрасчетный.РасчетыСПоставщиками;
		Движение.Период = Дата;
		Движение.Сумма = Выборка.Стоимость * КурсВалюты;
		Движение.КоличествоДт = Выборка.Количество;
		Движение.СубконтоДт[ПланыВидовХарактеристик.ВидыСубконто.Номенклатура] = Выборка.Номенклатура;
		Движение.СубконтоДт[ПланыВидовХарактеристик.ВидыСубконто.Склады] = Склад;
		Движение.СубконтоДт[ПланыВидовХарактеристик.ВидыСубконто.Партии] = Ссылка;
		Движение.СубконтоКт[ПланыВидовХарактеристик.ВидыСубконто.Контрагенты] = Поставщик;
		Движение.СубконтоКт[ПланыВидовХарактеристик.ВидыСубконто.Договоры] = Договор;

	КонецЦикла;	

		// регистр Хозрасчетный  
		//Дт60.01 - Кт60.02 Зачет аванса, погашение задолженности перед поставщиком   
		Движение2 = Движения.Хозрасчетный.Добавить();
		Движение2.СчетДт = ПланыСчетов.Хозрасчетный.РасчетыСПоставщиками;
		Движение2.СчетКт = ПланыСчетов.Хозрасчетный.РасчетыПоАвансамВыданным;
		Движение2.Период = Дата;
		Движение2.Сумма = ИтоговаяСумма * КурсВалюты;
		Движение2.СубконтоДт[ПланыВидовХарактеристик.ВидыСубконто.Контрагенты] = Поставщик; 
		Движение2.СубконтоДт[ПланыВидовХарактеристик.ВидыСубконто.Договоры] = Договор;
		Движение2.СубконтоКт[ПланыВидовХарактеристик.ВидыСубконто.Контрагенты] = Поставщик;
		Движение2.СубконтоКт[ПланыВидовХарактеристик.ВидыСубконто.Договоры] = Договор; 


КонецПроцедуры

Процедура ОбработкаЗаполнения(ДанныеЗаполнения, СтандартнаяОбработка)
	
	Если ТипЗнч(ДанныеЗаполнения) = Тип("ДокументСсылка.ЗаказПоставщику") Тогда
		// Заполнение шапки
		Валюта        = ДанныеЗаполнения.Валюта;
		ИтоговаяСумма = ДанныеЗаполнения.ИтоговаяСумма;
		Поставщик     = ДанныеЗаполнения.Поставщик;
		Договор       = ДанныеЗаполнения.Договор;
		Склад         = ДанныеЗаполнения.Склад; 
		ВидЦены       = ДанныеЗаполнения.ВидЦены;
		
		Для Каждого ТекСтрокаТовары Из ДанныеЗаполнения.Товары Цикл
			НоваяСтрока = Товары.Добавить();
			НоваяСтрока.Количество = ТекСтрокаТовары.Количество;
			НоваяСтрока.Номенклатура = ТекСтрокаТовары.Номенклатура;
			НоваяСтрока.ЦенаЗакупочная = ТекСтрокаТовары.ЦенаЗакупочная;
			НоваяСтрока.Стоимость = ТекСтрокаТовары.Стоимость;			
		КонецЦикла; 		
	КонецЕсли;      
	
КонецПроцедуры
