﻿ Процедура ПередЗаписью(Отказ, РежимЗаписи, РежимПроведения)    	
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
		
	//нужно исключить влияние текущего документа
	//для этого создадим пустой набор записей: 	
	Движения.ТоварыНаСкладах.Записать(); 
	Движения.Хозрасчетный.Записать(); 
	
	
	//определить способ списания себестоимости (FIFO/LIFO)
	СпособСписания = РегистрыСведений.СпособыСписанияСебестоимости.ПолучитьПоследнее(Дата).СпособСписания;
	
	Если СпособСписания = Перечисления.СпособыСписанияСебестоимости.FIFO Тогда
		УБЫВ = "";	     
	ИначеЕсли СпособСписания = Перечисления.СпособыСписанияСебестоимости.LIFO Тогда
		УБЫВ = "УБЫВ";	     
	Иначе	
		Сообщить("Не установлен способ списания себестоимости!");
		Отказ = Истина;
	КонецЕсли;


	//проверить остаток товаров в разрезе склада    	
	Запрос = Новый Запрос;
	Запрос.Текст = 
		"ВЫБРАТЬ
		|	РеализацияТоваровТовары.Номенклатура КАК Номенклатура,
		|	СУММА(РеализацияТоваровТовары.Количество) КАК Количество,
		|	СУММА(РеализацияТоваровТовары.Стоимость) КАК Стоимость
		|ПОМЕСТИТЬ ВТ_ДокТЧ
		|ИЗ
		|	Документ.РеализацияТоваров.Товары КАК РеализацияТоваровТовары
		|ГДЕ
		|	РеализацияТоваровТовары.Ссылка = &Ссылка
		|
		|СГРУППИРОВАТЬ ПО
		|	РеализацияТоваровТовары.Номенклатура
		|
		|ИНДЕКСИРОВАТЬ ПО
		|	Номенклатура
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|ВЫБРАТЬ
		|	ЕСТЬNULL(ТоварыНаСкладахОстатки.КоличествоОстаток, 0) КАК КоличествоОстаток,
		|	ВТ_ДокТЧ.Номенклатура КАК Номенклатура,
		|	ВТ_ДокТЧ.Количество КАК Количество,
		|	ВТ_ДокТЧ.Стоимость КАК Стоимость,
		|	ЕСТЬNULL(ТоварыНаСкладахОстатки.СуммаОстаток, 0) КАК СуммаОстаток,
		|	ВТ_ДокТЧ.Номенклатура.Представление КАК НоменклатураПредставление,
		|	ТоварыНаСкладахОстатки.Партия КАК Партия
		|ИЗ
		|	ВТ_ДокТЧ КАК ВТ_ДокТЧ
		|		ЛЕВОЕ СОЕДИНЕНИЕ РегистрНакопления.ТоварыНаСкладах.Остатки(
		|				&МоментВремени,
		|				Номенклатура В
		|						(ВЫБРАТЬ РАЗЛИЧНЫЕ
		|							ВТ_ДокТЧ.Номенклатура КАК Номенклатура
		|						ИЗ
		|							ВТ_ДокТЧ КАК ВТ_ДокТЧ)
		|					И Склад = &Склад) КАК ТоварыНаСкладахОстатки
		|		ПО ВТ_ДокТЧ.Номенклатура = ТоварыНаСкладахОстатки.Номенклатура
		|
		|УПОРЯДОЧИТЬ ПО
		|	ТоварыНаСкладахОстатки.Партия.Дата " + УБЫВ + "
		|ИТОГИ
		|	СУММА(КоличествоОстаток),
		|	МАКСИМУМ(Количество),
		|	МАКСИМУМ(Стоимость),
		|	СУММА(СуммаОстаток)
		|ПО
		|	Номенклатура";
	
	Запрос.УстановитьПараметр("МоментВремени", МоментВремени());
	Запрос.УстановитьПараметр("Склад", Склад);
	Запрос.УстановитьПараметр("Ссылка", Ссылка);
	
	РезультатЗапроса = Запрос.Выполнить();
	ВыборкаНоменклатура = РезультатЗапроса.Выбрать(ОбходРезультатаЗапроса.ПоГруппировкам); 
			
	Пока ВыборкаНоменклатура.Следующий() Цикл  
		
		//если требуется реализовать товара больше, чем есть на складе, выдать сообщение и отменить проведение 
		Если ВыборкаНоменклатура.Количество > ВыборкаНоменклатура.КоличествоОстаток тогда         
			
			КоличествоНедостаточно = ВыборкаНоменклатура.Количество - ВыборкаНоменклатура.КоличествоОстаток;
			Сообщить("На складе " + Склад + " недостаточно товара " + ВыборкаНоменклатура.НоменклатураПредставление 
			+ "! Не хватает " +  КоличествоНедостаточно + " шт.");			
			Отказ = Истина;	     
			
		КонецЕсли;     
				
		Если НЕ Отказ тогда  			
			ОсталосьСписать = ВыборкаНоменклатура.Количество;
			Выборка = ВыборкаНоменклатура.Выбрать();

			Пока Выборка.Следующий() И ОсталосьСписать > 0 Цикл
				
				// регистр ТоварыНаСкладах Расход
				Движение = Движения.ТоварыНаСкладах.Добавить();   
				
				Движение.ВидДвижения = ВидДвиженияНакопления.Расход;
				Движение.Период = Дата;  
				Движение.Склад = Склад; 
				Движение.Партия = Выборка.Партия;
				Движение.Номенклатура = Выборка.Номенклатура;
				Движение.Количество = мин(ОсталосьСписать,Выборка.КоличествоОстаток); 
				
				//если списывается вся партия, то списывается вся оставшаяся сумма (чтобы не оставалось копеек)
				Если Движение.Количество = Выборка.КоличествоОстаток Тогда 
					Движение.Сумма = Выборка.СуммаОстаток;
				Иначе
					Движение.Сумма = Выборка.СуммаОстаток / Выборка.КоличествоОстаток * Движение.Количество;  
				КонецЕсли;   
				
				ОсталосьСписать = ОсталосьСписать - Движение.Количество; 
				
			КонецЦикла; 			
		КонецЕсли;   
				
	КонецЦикла; 
	
	
	//БУ 
	
	Запрос = Новый Запрос;
	Запрос.Текст = 
		"ВЫБРАТЬ
		|	РеализацияТоваровТовары.Номенклатура КАК Номенклатура,
		|	СУММА(РеализацияТоваровТовары.Количество) КАК Количество,
		|	СУММА(РеализацияТоваровТовары.Стоимость) КАК Стоимость
		|ПОМЕСТИТЬ ВТ_ДокТЧ
		|ИЗ
		|	Документ.РеализацияТоваров.Товары КАК РеализацияТоваровТовары
		|ГДЕ
		|	РеализацияТоваровТовары.Ссылка = &Ссылка
		|
		|СГРУППИРОВАТЬ ПО
		|	РеализацияТоваровТовары.Номенклатура
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|ВЫБРАТЬ
		|	ВТ_ДокТЧ.Номенклатура КАК Номенклатура,
		|	ВТ_ДокТЧ.Количество КАК Количество,
		|	ВТ_ДокТЧ.Стоимость КАК Стоимость,
		|	ЕСТЬNULL(ХозрасчетныйОстатки.СуммаОстатокДт, 0) КАК СуммаОстатокПоВсем,
		|	ЕСТЬNULL(ХозрасчетныйОстатки.КоличествоОстатокДт, 0) КАК КоличествоОстатокПоВсем,
		|	ВТ_ДокТЧ.Номенклатура.Представление КАК НоменклатураПредставление
		|ИЗ
		|	ВТ_ДокТЧ КАК ВТ_ДокТЧ
		|		ЛЕВОЕ СОЕДИНЕНИЕ РегистрБухгалтерии.Хозрасчетный.Остатки(
		|				&МоментВремени,
		|				Счет = ЗНАЧЕНИЕ(ПланСчетов.Хозрасчетный.ТоварыНаСкладах),
		|				&СубконтоТовары,
		|				Субконто1 В
		|					(ВЫБРАТЬ РАЗЛИЧНЫЕ
		|						ВТ_ДокТЧ.Номенклатура КАК Номенклатура
		|					ИЗ
		|						ВТ_ДокТЧ КАК ВТ_ДокТЧ)) КАК ХозрасчетныйОстатки
		|		ПО ВТ_ДокТЧ.Номенклатура = ХозрасчетныйОстатки.Субконто1";              
	
	СубконтоТовары = Новый Массив;
	СубконтоТовары.Добавить(ПланыВидовХарактеристик.ВидыСубконто.Номенклатура);
	
	Запрос.УстановитьПараметр("МоментВремени", МоментВремени());
	Запрос.УстановитьПараметр("Ссылка", Ссылка);
	Запрос.УстановитьПараметр("СубконтоТовары", СубконтоТовары);
	
	РезультатЗапроса = Запрос.Выполнить();	
	Выборка = РезультатЗапроса.Выбрать(); 
			
	Пока Выборка.Следующий() Цикл   		
		
		Себестоимость1штСредняя = Выборка.СуммаОстатокПоВсем / Выборка.КоличествоОстатокПоВсем;
				
		// регистр Хозрасчетный   
		// Дт90.02 - Кт41.01 (Себестоимость продаж - Товары на складах) 
		Движение = Движения.Хозрасчетный.Добавить();
		Движение.СчетДт = ПланыСчетов.Хозрасчетный.СебестоимостьПродаж;
		Движение.СчетКт = ПланыСчетов.Хозрасчетный.ТоварыНаСкладах;
		Движение.Период = Дата;
		Движение.КоличествоКт = Выборка.Количество; 
		Движение.Сумма  =Движение.КоличествоКт * Себестоимость1штСредняя;      
		Движение.СубконтоДт[ПланыВидовХарактеристик.ВидыСубконто.Номенклатура] = Выборка.Номенклатура;
		Движение.СубконтоКт[ПланыВидовХарактеристик.ВидыСубконто.Номенклатура] = Выборка.Номенклатура;
		Движение.СубконтоКт[ПланыВидовХарактеристик.ВидыСубконто.Склады] 	   = Склад;
		Движение.СубконтоКт[ПланыВидовХарактеристик.ВидыСубконто.Партии]       = Ссылка;  
		
	КонецЦикла; 					
		
		// регистр Хозрасчетный 
		//Дт62.01 - Кт90.01 (Расчеты с покупателями - Выручка)
		Движение2 = Движения.Хозрасчетный.Добавить();
		Движение2.СчетДт = ПланыСчетов.Хозрасчетный.РасчетыСПокупателями;
		Движение2.СчетКт = ПланыСчетов.Хозрасчетный.Выручка;
		Движение2.Период = Дата;
		Движение2.Сумма  = ИтоговаяСумма * КурсВалюты;
		Движение2.СубконтоДт[ПланыВидовХарактеристик.ВидыСубконто.Контрагенты] = Покупатель; 
		Движение2.СубконтоДт[ПланыВидовХарактеристик.ВидыСубконто.Договоры] = Договор;
		Движение2.СубконтоКт[ПланыВидовХарактеристик.ВидыСубконто.Контрагенты] = Покупатель;   
		КонецПроцедуры

Процедура ОбработкаЗаполнения(ДанныеЗаполнения, СтандартнаяОбработка)

	Если ТипЗнч(ДанныеЗаполнения) = Тип("ДокументСсылка.ЗаказКлиента") Тогда
		// Заполнение шапки
		Валюта        = ДанныеЗаполнения.Валюта;
		ИтоговаяСумма = ДанныеЗаполнения.ИтоговаяСумма;
		Покупатель    = ДанныеЗаполнения.Покупатель;
		Договор       = ДанныеЗаполнения.Договор;
		Склад         = ДанныеЗаполнения.Склад;    
		ВидЦены       = ДанныеЗаполнения.ВидЦены;
		
		Для Каждого ТекСтрокаТовары Из ДанныеЗаполнения.Товары Цикл
			НоваяСтрока = Товары.Добавить();
			НоваяСтрока.Количество = ТекСтрокаТовары.Количество;
			НоваяСтрока.Номенклатура = ТекСтрокаТовары.Номенклатура;
			НоваяСтрока.Стоимость = ТекСтрокаТовары.Стоимость;
			НоваяСтрока.ЦенаРеализации = ТекСтрокаТовары.ЦенаРеализации;
		КонецЦикла;
	КонецЕсли;

КонецПроцедуры
