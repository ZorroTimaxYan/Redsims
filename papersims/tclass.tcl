Class Die

Die instproc speak {} {
	$self instvar name
	set name 你爹
	puts 说鸟语
}

Die instproc eat {} {
	puts 吃生的
}

Class Zai -superclass Die

Zai instproc speak {} {
	$self instvar name
	puts 说中国话
	$self next
	puts $name
	puts 结束啦
}

Zai z
z speak
z eat
