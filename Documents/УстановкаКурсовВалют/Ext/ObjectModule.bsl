﻿
Процедура ОбработкаПроведения(Отказ, Режим)
	// регистр КурсыВалют
	Движения.КурсыВалют.Записывать = Истина;
	Для Каждого ТекСтрокаКурсыВалют Из КурсыВалют Цикл
		Движение = Движения.КурсыВалют.Добавить();
		Движение.Период = Дата;
		Движение.Валюта = ТекСтрокаКурсыВалют.Валюта;
		Движение.Курс = ТекСтрокаКурсыВалют.Курс;
	КонецЦикла;
КонецПроцедуры
