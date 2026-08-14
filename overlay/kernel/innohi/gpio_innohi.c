#ifndef _A133_PLATFORM_INNOHI_
#include <dt-bindings/gpio/gpio.h>
#endif
#include <linux/gpio.h>
#include <linux/of_gpio.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/fb.h>
#include <linux/backlight.h>
#include <linux/err.h>
#include <linux/pwm.h>
#include <linux/pwm_backlight.h>
#include <linux/slab.h>
#include <linux/device.h>
#include <linux/miscdevice.h>
#include <asm/uaccess.h>
#include <linux/string.h>
#include <linux/sysfs.h>
#include <linux/delay.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/gpio/consumer.h>
#include <linux/syscore_ops.h>
#include <linux/version.h>
#ifdef _A527_PLATFORM_INNOHI_
#include <sunxi-gpio.h>
#endif
#ifdef _A133_PLATFORM_INNOHI_
#include <linux/sunxi-gpio.h>
#endif

#define SYSCORE_POWER_OFF

#define DRV_NAME "gpio_innohi"

struct gpio_data
{
	unsigned long key;
	int use;
	int gpio;
	int direction;
	int value;
};

static const struct of_device_id of_gpio_match[] = {
        { .compatible = "gpio-innohi", },
        {},
};

MODULE_DEVICE_TABLE(of, of_gpio_match);

static	struct class * pclass = NULL;
#define MAX_GPIO_DATA (100)
static struct gpio_data datas[MAX_GPIO_DATA] = {0};

static struct gpio_data *find_gpio_data(struct device *dev)
{
	int i = 0;
	unsigned long pdev = (unsigned long)dev;
	struct gpio_data *pdata = NULL;
	if(dev == NULL)
	{
		return NULL;
	}
	for(i = 0; i < MAX_GPIO_DATA ; i++)
	{
		if(datas[i].use == 1 && datas[i].key == pdev)
		{
			pdata = &datas[i];
			break;
		}
	}
	return pdata;
}
static ssize_t direction_store(struct device *dev, struct device_attribute *attr, const char *buf, size_t len)
{
	struct gpio_data *pdata = NULL;
	int ret = 0;
	pdata = find_gpio_data(dev);
	if(pdata != NULL)
	{
		if(!strncasecmp(buf,"out",3))
		{
			pdata->direction = 1;
			ret = gpio_direction_output(pdata->gpio, pdata->direction);
			if (ret)
			{
				printk("%s %s[%d] failed to gpio_direction_output  for you ret:%d\n", __FILE__,__FUNCTION__,__LINE__, ret);
				return len;
			}
		}else if(!strncasecmp(buf,"in",2))
		{
			pdata->direction = 0;
			ret = gpio_direction_input(pdata->gpio);
			if (ret)
			{
				printk("%s %s[%d] failed to gpio_direction_input  for you ret:%d\n", __FILE__,__FUNCTION__,__LINE__, ret);
				return -1;
			}
		}
	}
	return len;
}
static ssize_t direction_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct gpio_data *pdata = NULL;
	pdata = find_gpio_data(dev);

	if(pdata != NULL)
	{
		if(pdata->direction == 1)
		{
			return sprintf(buf, "out\n");
		}else if(pdata->direction == 0)
		{
			return sprintf(buf, "in\n");
		}
	}
	return 0;
}

static ssize_t value_store(struct device *dev, struct device_attribute *attr, const char *buf, size_t len)
{
	struct gpio_data *pdata = NULL;
	if (buf[0] != '1' && buf[0] != '0')
	{
		return len;
	}

	pdata = find_gpio_data(dev);
	if(pdata != NULL)
	{
		if (buf[0] == '1')
		{
			gpio_set_value(pdata->gpio, 1);
		}else if (buf[0] == '0')
		{
			gpio_set_value(pdata->gpio, 0);
		}
	}
	return len;
}

static ssize_t value_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct gpio_data *pdata = NULL;
	int gpio_value = 0;
	pdata = find_gpio_data(dev);

	if(pdata != NULL)
	{
		gpio_value = gpio_get_value(pdata->gpio);
		return sprintf(buf, "%d\n",gpio_value);
	}
	return 0;
}

static DEVICE_ATTR(direction, 0664, direction_show, direction_store);
static DEVICE_ATTR(value,  0664, value_show, value_store);
static struct attribute *gpio_child_dev_attrs[] =
{
	&dev_attr_direction.attr,
	&dev_attr_value.attr,
	NULL
};

ATTRIBUTE_GROUPS(gpio_child_dev);


#ifdef SYSCORE_POWER_OFF
/*
 * 关机所有io 都拉低
 */
static void gpio_shutdown_power(void)
{
	int i = 0;
	struct gpio_data *pdata = NULL;
	printk("%s %s[%d] \n",__FILE__,__FUNCTION__,__LINE__);
	for(i = 0; i < MAX_GPIO_DATA ; i++)
	{
		if(datas[i].use == 1)
		{
			pdata = &datas[i];
			gpio_direction_output(pdata->gpio, 0);
			gpio_set_value(pdata->gpio, 0);
		}
	}
}

/*
 * For PMIC that power off supplies by write register via i2c bus,
 * it's better to do power off at syscore shutdown here.
 *
 * Because when run to kernel's "pm_power_off" call, i2c may has
 * been stopped or PMIC may not be able to get i2c transfer while
 * there are too many devices are competiting.
 */

static struct syscore_ops gpio_syscore_ops = {
	.shutdown = gpio_shutdown_power,
};

#endif

static int gpio_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct fwnode_handle *child;
	int count , ret;
	int index = 0;
#if (defined _A527_PLATFORM_INNOHI_) || (defined _A133_PLATFORM_INNOHI_)
	struct gpio_config gpio_flags;
#endif

	memset(datas,0,sizeof(datas));
	pclass = class_create(THIS_MODULE,DRV_NAME);
	if (IS_ERR(pclass))
	{
		printk("%s %s[%d] class_create error \n",__FILE__,__FUNCTION__,__LINE__);
		return -1;
	}

	count = device_get_child_node_count(dev);
	if (!count)
	{
		printk("%s %s[%d] no child \n",__FILE__,__FUNCTION__,__LINE__);
		return -1;
	}

	device_for_each_child_node(dev, child){
		struct device * subdev = NULL;
		const char *mode = NULL;
		const char *value = NULL;
		const char *label = NULL;
#ifndef _A527_PLATFORM_INNOHI_
		struct gpio_desc *gpiod = NULL;
#endif
		int gpio = -1;
		int gpio_value = 1;
		int gpio_direction = 1;

#ifdef _A133_PLATFORM_INNOHI_
//A133 KERNEL_VERSION(4, 9, 170)
		fwnode_property_read_string(child, "default_mode", &mode);
		fwnode_property_read_string(child, "default_value", &value);
#else
		fwnode_property_read_string(child, "default-mode", &mode);
		fwnode_property_read_string(child, "default-value", &value);
#endif
		fwnode_property_read_string(child, "label", &label);

		if(label == NULL || mode == NULL)
		{
			printk("%s %s[%d] devm_fwnode_get_gpiod_from_child fail , label %s or  mode %s  empty\n",__FILE__,__FUNCTION__,__LINE__,label, mode);
			continue;
		}
#if (defined _A527_PLATFORM_INNOHI_) || (defined _A133_PLATFORM_INNOHI_)
		gpio = of_get_named_gpio_flags(to_of_node(child), "gpios", 0,(enum of_gpio_flags *)&gpio_flags);
		if (!gpio_is_valid(gpio)) {
			printk("%s %s[%d] of_get_named_gpio_flags %s fail \n",__FILE__,__FUNCTION__,__LINE__,label);
			return -1;
		}
#else
		gpiod = devm_fwnode_get_gpiod_from_child(dev, NULL, child, GPIOD_ASIS, label);
		if (IS_ERR(gpiod) || gpiod == NULL) {
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6,1,0) 			
			gpiod = fwnode_gpiod_get_index(child,"reset-gpios",0 ,0 ,label);
#else
			gpiod = fwnode_get_named_gpiod(child,"reset-gpios",0 ,0 ,label);
#endif
			if (IS_ERR(gpiod) || gpiod == NULL) {
				printk("%s %s[%d] no child \n",__FILE__,__FUNCTION__,__LINE__);
				continue;
			}
		}
		if(IS_ERR(gpiod) || gpiod == NULL)
		{
			printk("%s %s[%d] no child \n",__FILE__,__FUNCTION__,__LINE__);
			continue;
		}
		gpio = desc_to_gpio(gpiod);
#endif
		if(!strncasecmp(mode,"in",2))
		{
			gpio_direction = 0;
		}
		if(gpio_direction == 1)
		{
			if(!strncasecmp(value,"0",1))
			{
				gpio_value = 0;
			}
			ret = gpio_direction_output(gpio, gpio_value);
			if (ret)
			{
				printk("%s %s[%d] failed to gpio_direction_output %s  for you ret:%d\n", __FILE__,__FUNCTION__,__LINE__, label, ret);
				return -1;
			}
			gpio_set_value(gpio, gpio_value);
		}else
		{
			ret = gpio_direction_input(gpio);
			if (ret)
			{
				printk("%s %s[%d] failed to gpio_direction_input  %s for you ret:%d\n", __FILE__,__FUNCTION__,__LINE__, label, ret);
				return -1;
			}
		}

		subdev = device_create_with_groups(pclass, dev, 0, NULL, gpio_child_dev_groups, label);
		if (IS_ERR(subdev))
		{
			printk("%s %s[%d] device_create_with_groups %s fail \n",__FILE__,__FUNCTION__,__LINE__,label);
			return -1;
		}

		printk("%s %s[%d] %s %d default %s %s \n",__FILE__,__FUNCTION__,__LINE__,label , gpio, mode, value);

		datas[index].use = 1;
		datas[index].gpio = gpio;
		datas[index].direction = gpio_direction;
		datas[index].value = gpio_value;
		datas[index].key = (unsigned long)subdev;
		index++;
	}

#ifdef SYSCORE_POWER_OFF
	/* power off system in the syscore shutdown ! */
	register_syscore_ops(&gpio_syscore_ops);
#endif

	printk("%s %s[%d] ok \n",__FILE__,__FUNCTION__,__LINE__);
	return 0;
}

static struct platform_driver gpio_driver = {
        .probe          = gpio_probe,
        .driver         = {
                .name   = "gpio",
                .of_match_table = of_gpio_match,
        },
};

static int __init gpio_innohi_init(void)
{
	return platform_driver_register(&gpio_driver);
}

late_initcall(gpio_innohi_init);

MODULE_DESCRIPTION("innohi gpio driver");
MODULE_LICENSE("GPL");
MODULE_ALIAS("platform:innohi");
